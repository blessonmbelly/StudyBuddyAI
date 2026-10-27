from fastapi import APIRouter, HTTPException
from ..models import QuizGenerateRequest, QuizGenerateResponse
from ..gemini_service import generate_quiz_questions

router = APIRouter(prefix="/api/quiz", tags=["Quiz"])

@router.post("/generate", response_model=QuizGenerateResponse)
async def generate_quiz(req: QuizGenerateRequest):
    """
    Generates 5 multiple choice questions with exactly 4 options, 1 correct answer,
    explanations, hints, and concept tags based on the student's study text.
    """
    cleaned_text = req.text.strip()
    if not cleaned_text:
        raise HTTPException(status_code=400, detail="Cannot generate quiz from empty text.")

    if len(cleaned_text) < 15:
        raise HTTPException(
            status_code=400,
            detail="Study text is too short to generate quiz questions. Please provide more content."
        )

    num_qs = req.num_questions if (1 <= req.num_questions <= 10) else 5
    quiz = generate_quiz_questions(
        text=cleaned_text,
        num_questions=num_qs,
        note_title=req.note_title,
    )
    return quiz
