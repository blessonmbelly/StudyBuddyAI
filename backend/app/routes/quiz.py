from decimal import Decimal
from typing import List, Optional
import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..auth import get_current_user, get_optional_current_user
from ..database import get_db
from ..db_models import Quiz, QuizAttempt, User
from ..gemini_service import generate_quiz_questions
from ..models import (
    MessageResponse,
    QuizAttemptCreateRequest,
    QuizAttemptResponse,
    QuizGenerateRequest,
    QuizGenerateResponse,
    QuizResponse,
)

router = APIRouter(prefix="/api/quiz", tags=["Quiz"])


@router.post("/generate", response_model=QuizGenerateResponse)
async def generate_quiz(
    req: QuizGenerateRequest,
    current_user: Optional[User] = Depends(get_optional_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Generates 5 multiple choice questions with explanations, hints, and concept tags.
    When invoked by an authenticated user, persists the quiz in PostgreSQL.
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
    quiz_data = generate_quiz_questions(
        text=cleaned_text,
        num_questions=num_qs,
        note_title=req.note_title,
    )

    quiz_id_str = None
    if current_user:
        try:
            doc_uuid = uuid.UUID(req.document_id) if req.document_id else None
            note_uuid = uuid.UUID(req.note_id) if req.note_id else None

            # Serialize questions to JSONB
            questions_json = [q.model_dump() for q in quiz_data.questions]

            db_quiz = Quiz(
                id=uuid.uuid4(),
                user_id=current_user.id,
                document_id=doc_uuid,
                note_id=note_uuid,
                title=req.note_title or "Quick Practice Quiz",
                subject="Study Material",
                total_questions=len(quiz_data.questions),
                questions=questions_json,
            )
            db.add(db_quiz)
            await db.commit()
            await db.refresh(db_quiz)
            quiz_id_str = str(db_quiz.id)
            quiz_data.quiz_id = quiz_id_str
        except Exception:
            await db.rollback()

    return quiz_data


@router.get("", response_model=List[QuizResponse])
async def list_quizzes(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Lists all saved quizzes belonging to the authenticated student.
    """
    stmt = (
        select(Quiz)
        .where(Quiz.user_id == current_user.id)
        .order_by(Quiz.created_at.desc())
    )
    result = await db.execute(stmt)
    quizzes = result.scalars().all()

    return [
        QuizResponse(
            id=str(q.id),
            title=q.title,
            subject=q.subject,
            total_questions=q.total_questions,
            questions=q.questions or [],
            created_at=q.created_at,
            document_id=str(q.document_id) if q.document_id else None,
            note_id=str(q.note_id) if q.note_id else None,
        )
        for q in quizzes
    ]


@router.get("/attempts/all", response_model=List[QuizAttemptResponse])
async def list_all_attempts(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Retrieves all quiz attempts for the authenticated student across all quizzes.
    """
    stmt = (
        select(QuizAttempt)
        .where(QuizAttempt.user_id == current_user.id)
        .order_by(QuizAttempt.created_at.desc())
    )
    result = await db.execute(stmt)
    attempts = result.scalars().all()

    return [
        QuizAttemptResponse(
            id=str(a.id),
            quiz_id=str(a.quiz_id),
            user_id=str(a.user_id),
            score=a.score,
            total_questions=a.total_questions,
            percentage=float(a.percentage),
            time_spent_seconds=a.time_spent_seconds,
            user_answers=a.user_answers or {},
            created_at=a.created_at,
        )
        for a in attempts
    ]


@router.post("/{quiz_id}/attempt", response_model=QuizAttemptResponse, status_code=status.HTTP_201_CREATED)
async def record_quiz_attempt(
    quiz_id: str,
    req: QuizAttemptCreateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Records a student's score and answers for a specific quiz attempt.
    """
    try:
        q_uuid = uuid.UUID(quiz_id)
    except (ValueError, TypeError):
        raise HTTPException(status_code=400, detail="Invalid quiz ID format.")

    stmt = select(Quiz).where(Quiz.id == q_uuid, Quiz.user_id == current_user.id)
    result = await db.execute(stmt)
    quiz = result.scalar_one_or_none()

    if not quiz:
        raise HTTPException(status_code=404, detail="Quiz not found.")

    total = req.total_questions if req.total_questions > 0 else quiz.total_questions
    percentage = round(Decimal((req.score / total) * 100), 2)

    attempt = QuizAttempt(
        id=uuid.uuid4(),
        quiz_id=quiz.id,
        user_id=current_user.id,
        score=req.score,
        total_questions=total,
        percentage=percentage,
        time_spent_seconds=req.time_spent_seconds,
        user_answers=req.user_answers or {},
    )
    db.add(attempt)
    await db.commit()
    await db.refresh(attempt)

    return QuizAttemptResponse(
        id=str(attempt.id),
        quiz_id=str(attempt.quiz_id),
        user_id=str(attempt.user_id),
        score=attempt.score,
        total_questions=attempt.total_questions,
        percentage=float(attempt.percentage),
        time_spent_seconds=attempt.time_spent_seconds,
        user_answers=attempt.user_answers or {},
        created_at=attempt.created_at,
    )


@router.get("/{quiz_id}/attempts", response_model=List[QuizAttemptResponse])
async def list_quiz_attempts(
    quiz_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Retrieves attempts for a specific quiz, enforcing per-user data isolation.
    """
    try:
        q_uuid = uuid.UUID(quiz_id)
    except (ValueError, TypeError):
        raise HTTPException(status_code=400, detail="Invalid quiz ID format.")

    stmt = (
        select(QuizAttempt)
        .where(QuizAttempt.quiz_id == q_uuid, QuizAttempt.user_id == current_user.id)
        .order_by(QuizAttempt.created_at.desc())
    )
    result = await db.execute(stmt)
    attempts = result.scalars().all()

    return [
        QuizAttemptResponse(
            id=str(a.id),
            quiz_id=str(a.quiz_id),
            user_id=str(a.user_id),
            score=a.score,
            total_questions=a.total_questions,
            percentage=float(a.percentage),
            time_spent_seconds=a.time_spent_seconds,
            user_answers=a.user_answers or {},
            created_at=a.created_at,
        )
        for a in attempts
    ]
