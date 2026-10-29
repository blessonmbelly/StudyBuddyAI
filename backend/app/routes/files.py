import os
from typing import Optional, List
import uuid
from fastapi import APIRouter, File, UploadFile, HTTPException, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from ..config import settings
from ..auth import get_optional_current_user
from ..database import get_db
from ..db_models import Document, User
from ..models import (
    ExtractionResponse,
    DocumentOrganizeRequest,
    DocumentOrganizeResponse,
)
from ..document_parser import (
    validate_file,
    extract_from_txt,
    extract_from_docx,
    extract_from_pdf,
    validate_image,
)
from ..gemini_service import perform_gemini_ocr, organize_study_document

router = APIRouter(prefix="/api/files", tags=["Files"])

@router.post("/extract", response_model=ExtractionResponse)
async def extract_file_content(
    file: UploadFile = File(...),
    current_user: Optional[User] = Depends(get_optional_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Extracts text from uploaded study material:
    Supports TXT, DOCX, text-based PDF, scanned PDF, JPG, and PNG.
    Prioritizes embedded PDF text before falling back to OCR.
    Automatically generates a meaningful document title, identifies subject, and extracts topics.
    When invoked by an authenticated student, automatically persists the document to PostgreSQL.
    """
    content = await file.read()
    filename = file.filename or "uploaded_file"
    ext = validate_file(filename, len(content), settings.MAX_UPLOAD_SIZE_BYTES)
    
    extracted_text = ""
    method = "embedded_text"
    page_count = 1

    try:
        if ext == ".txt":
            extracted_text, page_count = extract_from_txt(content)
            method = "plain_text"

        elif ext == ".docx":
            extracted_text, page_count = extract_from_docx(content)
            method = "docx_parser"

        elif ext == ".pdf":
            raw_text, page_count, is_scanned = extract_from_pdf(content)
            if not is_scanned and raw_text:
                extracted_text = raw_text
                method = "pdf_embedded_text"
            else:
                # Scanned or image-based PDF: perform multimodal OCR across all document pages
                extracted_text = perform_gemini_ocr(content, mime_type="application/pdf")
                method = "gemini_pdf_ocr"

        elif ext in {".jpg", ".jpeg", ".png"}:
            mime_type = "image/png" if ext == ".png" else "image/jpeg"
            validate_image(content)
            extracted_text = perform_gemini_ocr(content, mime_type=mime_type)
            method = "gemini_vision_ocr"
            page_count = 1

        else:
            raise HTTPException(status_code=400, detail=f"Unsupported file format: {ext}")

    finally:
        # Avoid retaining uploaded material unnecessarily
        del content

    words = len(extracted_text.split()) if extracted_text else 0
    doc_id = f"doc_{uuid.uuid4().hex[:10]}"

    # Automatically organize document with smart metadata
    org_data = organize_study_document(extracted_text, filename=filename)

    # Persist in PostgreSQL for authenticated user
    if current_user:
        try:
            new_doc = Document(
                id=uuid.uuid4(),
                user_id=current_user.id,
                title=org_data["title"],
                original_filename=filename,
                file_type=ext.replace(".", "").upper(),
                subject=org_data["subject"],
                topics=org_data["topics"],
                extracted_text=extracted_text,
                word_count=words,
                page_count=page_count,
                extraction_method=method,
                processing_status=org_data["processing_status"],
            )
            db.add(new_doc)
            await db.commit()
            await db.refresh(new_doc)
            doc_id = str(new_doc.id)
        except Exception as e:
            await db.rollback()
            # If persistence fails, still return extracted text so user flow is not broken
            pass

    return ExtractionResponse(
        document_id=doc_id,
        filename=filename,
        file_type=ext.replace(".", "").upper(),
        extracted_text=extracted_text,
        word_count=words,
        extraction_method=method,
        page_count=page_count,
        success=True,
        generated_title=org_data["title"],
        detected_subject=org_data["subject"],
        topics=org_data["topics"],
        processing_status=org_data["processing_status"],
    )


@router.post("/extract-multiple", response_model=ExtractionResponse)
async def extract_multiple_files(
    files: List[UploadFile] = File(...),
    current_user: Optional[User] = Depends(get_optional_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Extracts and combines text from multiple uploaded images or documents in one session.
    Preserves exact page order, extracts text from each page via OCR / parser,
    combines them with page separators, organizes metadata, and persists to PostgreSQL.
    """
    if not files:
        raise HTTPException(status_code=400, detail="No files provided for extraction.")

    extracted_pages: List[tuple] = []
    failed_pages: List[int] = []
    total_files = len(files)

    for index, file in enumerate(files, start=1):
        content = await file.read()
        filename = file.filename or f"page_{index}"
        try:
            ext = validate_file(filename, len(content), settings.MAX_UPLOAD_SIZE_BYTES)
            page_text = ""
            if ext == ".txt":
                page_text, _ = extract_from_txt(content)
            elif ext == ".docx":
                page_text, _ = extract_from_docx(content)
            elif ext == ".pdf":
                raw_text, _, is_scanned = extract_from_pdf(content)
                if not is_scanned and raw_text:
                    page_text = raw_text
                else:
                    page_text = perform_gemini_ocr(content, mime_type="application/pdf")
            elif ext in {".jpg", ".jpeg", ".png"}:
                mime_type = "image/png" if ext == ".png" else "image/jpeg"
                validate_image(content)
                page_text = perform_gemini_ocr(content, mime_type=mime_type)
            else:
                page_text = ""

            if page_text and page_text.strip():
                extracted_pages.append((index, filename, page_text.strip()))
            else:
                failed_pages.append(index)
        except Exception:
            failed_pages.append(index)
        finally:
            del content

    if not extracted_pages and failed_pages:
        raise HTTPException(
            status_code=400,
            detail=f"Failed to extract readable text from any of the {total_files} selected images or files.",
        )

    # Format combined text with page separators if multiple pages
    if total_files > 1:
        sections = []
        for page_num, fname, ptext in extracted_pages:
            sections.append(f"--- Page {page_num} ({fname}) ---\n{ptext}")
        combined_text = "\n\n".join(sections)
    else:
        combined_text = extracted_pages[0][2] if extracted_pages else ""

    words = len(combined_text.split()) if combined_text else 0
    doc_id = f"doc_{uuid.uuid4().hex[:10]}"
    combined_filename = f"Scan_{total_files}_pages" if total_files > 1 else (files[0].filename or "document")
    method = "multi_photo_ocr" if total_files > 1 else "gemini_vision_ocr"
    file_type = "SCAN" if total_files > 1 else "IMG"

    org_data = organize_study_document(combined_text, filename=combined_filename)

    if current_user:
        try:
            new_doc = Document(
                id=uuid.uuid4(),
                user_id=current_user.id,
                title=org_data["title"],
                original_filename=combined_filename,
                file_type=file_type,
                subject=org_data["subject"],
                topics=org_data["topics"],
                extracted_text=combined_text,
                word_count=words,
                page_count=total_files,
                extraction_method=method,
                processing_status=org_data["processing_status"],
            )
            db.add(new_doc)
            await db.commit()
            await db.refresh(new_doc)
            doc_id = str(new_doc.id)
        except Exception:
            await db.rollback()
            pass

    return ExtractionResponse(
        document_id=doc_id,
        filename=combined_filename,
        file_type=file_type,
        extracted_text=combined_text,
        word_count=words,
        extraction_method=method,
        page_count=total_files,
        success=True,
        generated_title=org_data["title"],
        detected_subject=org_data["subject"],
        topics=org_data["topics"],
        processing_status=org_data["processing_status"],
    )


@router.post("/organize", response_model=DocumentOrganizeResponse)
async def organize_text_content(
    request: DocumentOrganizeRequest,
    current_user: Optional[User] = Depends(get_optional_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Organizes raw or pasted study material text:
    Generates meaningful title, detects academic subject, and extracts topics.
    When invoked by an authenticated student, automatically persists the document.
    """
    words = len(request.text.split()) if request.text else 0
    doc_id = f"doc_{uuid.uuid4().hex[:10]}"
    filename = request.filename or "pasted_text"
    org_data = organize_study_document(request.text, filename=filename)

    if current_user:
        try:
            new_doc = Document(
                id=uuid.uuid4(),
                user_id=current_user.id,
                title=org_data["title"],
                original_filename=filename,
                file_type="TXT",
                subject=org_data["subject"],
                topics=org_data["topics"],
                extracted_text=request.text,
                word_count=words,
                page_count=request.page_count or 1,
                extraction_method="pasted_text" if not request.filename or request.filename == "pasted_text" else "OCR",
                processing_status=org_data["processing_status"],
            )
            db.add(new_doc)
            await db.commit()
            await db.refresh(new_doc)
            doc_id = str(new_doc.id)
        except Exception:
            await db.rollback()
            pass

    return DocumentOrganizeResponse(
        document_id=doc_id,
        title=org_data["title"],
        original_filename=filename,
        subject=org_data["subject"],
        topics=org_data["topics"],
        word_count=words,
        processing_status=org_data["processing_status"],
    )

