import os
from fastapi import APIRouter, File, UploadFile, HTTPException
from ..config import settings
from ..models import ExtractionResponse
from ..document_parser import (
    validate_file,
    extract_from_txt,
    extract_from_docx,
    extract_from_pdf,
    validate_image,
)
from ..gemini_service import perform_gemini_ocr

router = APIRouter(prefix="/api/files", tags=["Files"])

@router.post("/extract", response_model=ExtractionResponse)
async def extract_file_content(file: UploadFile = File(...)):
    """
    Extracts text from uploaded study material:
    Supports TXT, DOCX, text-based PDF, scanned PDF, JPG, and PNG.
    Prioritizes embedded PDF text before falling back to OCR.
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
                # Scanned PDF fallback
                if raw_text:
                    extracted_text = raw_text
                    method = "pdf_partial_text"
                else:
                    extracted_text = (
                        "Scanned PDF detected without embedded text layer. "
                        "Keep pages well-lit or convert individual pages to images for direct Vision OCR."
                    )
                    method = "scanned_pdf_notice"

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

    return ExtractionResponse(
        filename=filename,
        file_type=ext.replace(".", "").upper(),
        extracted_text=extracted_text,
        word_count=words,
        extraction_method=method,
        page_count=page_count,
        success=True,
    )
