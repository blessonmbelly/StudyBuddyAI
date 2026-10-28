import os
import uuid
from fastapi import APIRouter, File, UploadFile, HTTPException
from ..config import settings
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
async def extract_file_content(file: UploadFile = File(...)):
    """
    Extracts text from uploaded study material:
    Supports TXT, DOCX, text-based PDF, scanned PDF, JPG, and PNG.
    Prioritizes embedded PDF text before falling back to OCR.
    Automatically generates a meaningful document title, identifies subject, and extracts topics.
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

@router.post("/organize", response_model=DocumentOrganizeResponse)
async def organize_text_content(request: DocumentOrganizeRequest):
    """
    Organizes raw or pasted study material text:
    Generates meaningful title, detects academic subject, and extracts topics.
    """
    words = len(request.text.split()) if request.text else 0
    doc_id = f"doc_{uuid.uuid4().hex[:10]}"
    filename = request.filename or "pasted_text"
    org_data = organize_study_document(request.text, filename=filename)
    return DocumentOrganizeResponse(
        document_id=doc_id,
        title=org_data["title"],
        original_filename=filename,
        subject=org_data["subject"],
        topics=org_data["topics"],
        word_count=words,
        processing_status=org_data["processing_status"],
    )

