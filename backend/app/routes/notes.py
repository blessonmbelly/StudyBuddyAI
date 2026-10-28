from fastapi import APIRouter, HTTPException
from ..models import NoteGenerateRequest, NoteGenerateResponse
from ..gemini_service import generate_study_notes

router = APIRouter(prefix="/api/notes", tags=["Notes"])

@router.post("/generate", response_model=NoteGenerateResponse)
async def generate_notes(req: NoteGenerateRequest):
    """
    Generates a structured short note deck from raw extracted or pasted text.
    Includes title, summary, key definitions, and exam pitfalls.
    """
    cleaned_text = req.text.strip()
    if not cleaned_text:
        raise HTTPException(status_code=400, detail="Cannot generate notes from empty text.")

    if len(cleaned_text) < 15:
        raise HTTPException(
            status_code=400,
            detail="Text is too short to generate a meaningful study deck. Please provide at least a couple of sentences."
        )

    notes = generate_study_notes(
        text=cleaned_text,
        course_code=req.course_code,
        course_name=req.course_name,
        title=req.title,
    )
    return notes
