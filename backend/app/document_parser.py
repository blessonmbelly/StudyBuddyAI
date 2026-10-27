import io
import os
from typing import Tuple
from fastapi import HTTPException, UploadFile
from PIL import Image
import pypdf
import docx

ALLOWED_EXTENSIONS = {".txt", ".docx", ".pdf", ".jpg", ".jpeg", ".png"}

def validate_file(filename: str, file_size: int, max_bytes: int) -> str:
    """Validates file extension and size."""
    if not filename:
        raise HTTPException(status_code=400, detail="Missing filename.")
    
    ext = os.path.splitext(filename)[1].lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file format '{ext}'. Supported formats: TXT, DOCX, PDF, JPG, PNG."
        )

    if file_size > max_bytes:
        mb_limit = max_bytes // (1024 * 1024)
        raise HTTPException(
            status_code=400,
            detail=f"File exceeds the maximum upload limit of {mb_limit}MB."
        )

    if file_size == 0:
        raise HTTPException(status_code=400, detail="Uploaded file is empty.")

    return ext

def extract_from_txt(content: bytes) -> Tuple[str, int]:
    """Extract text from TXT with multiple encoding fallbacks."""
    for encoding in ("utf-8", "latin-1", "cp1252"):
        try:
            text = content.decode(encoding).strip()
            return text, 1
        except UnicodeDecodeError:
            continue
    raise HTTPException(status_code=400, detail="Unable to decode text file. Ensure UTF-8 or ASCII encoding.")

def extract_from_docx(content: bytes) -> Tuple[str, int]:
    """Extract paragraphs and table text from DOCX."""
    try:
        doc = docx.Document(io.BytesIO(content))
        paragraphs = [p.text for p in doc.paragraphs if p.text.strip()]
        for table in doc.tables:
            for row in table.rows:
                row_text = " | ".join(cell.text.strip() for cell in row.cells if cell.text.strip())
                if row_text:
                    paragraphs.append(row_text)
        text = "\n\n".join(paragraphs).strip()
        if not text:
            raise HTTPException(status_code=400, detail="DOCX document contains no readable text.")
        return text, 1
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to parse DOCX document: {str(e)}")

def extract_from_pdf(content: bytes) -> Tuple[str, int, bool]:
    """
    Extracts text from PDF.
    Returns (extracted_text, page_count, is_scanned).
    Prioritizes embedded PDF text before falling back to OCR.
    """
    try:
        reader = pypdf.PdfReader(io.BytesIO(content))
        page_count = len(reader.pages)
        if page_count == 0:
            raise HTTPException(status_code=400, detail="PDF contains 0 pages.")

        extracted_pages = []
        for i, page in enumerate(reader.pages):
            page_text = page.extract_text() or ""
            if page_text.strip():
                extracted_pages.append(page_text.strip())

        full_text = "\n\n".join(extracted_pages).strip()
        
        # If average extracted characters per page is very low (< 30 chars), it's likely a scanned image PDF
        is_scanned = len(full_text) < (page_count * 30)
        
        return full_text, page_count, is_scanned
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to read PDF document: {str(e)}")

def validate_image(content: bytes) -> Tuple[int, int, str]:
    """Validates image integrity and returns (width, height, format)."""
    try:
        img = Image.open(io.BytesIO(content))
        img.verify()
        # Re-open to read dimensions since verify closes the handle
        img = Image.open(io.BytesIO(content))
        return img.width, img.height, (img.format or "JPEG").lower()
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid or corrupted image file: {str(e)}")
