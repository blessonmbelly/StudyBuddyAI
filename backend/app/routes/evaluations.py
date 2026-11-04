import logging
from typing import Optional
import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..auth import get_current_user, get_optional_current_user
from ..database import get_db
from ..db_models import Document, NoteEvaluation, User
from ..gemini_service import evaluate_note_quality
from ..models import (
    NoteEvaluationCreateRequest,
    NoteEvaluationResponse,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/evaluations", tags=["Note Quality Evaluation"])


@router.post("/document/{document_id}", response_model=NoteEvaluationResponse)
async def evaluate_document(
    document_id: str,
    force_refresh: bool = False,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Evaluates an uploaded document's content for:
    1. Topic relevance
    2. Factual accuracy (with claim verification & counter-evidence)
    3. Content completeness (identifying missing important topics)
    Enforces strict epistemic caution.
    Persists evaluation results in PostgreSQL associated with the document and student.
    """
    try:
        doc_uuid = uuid.UUID(document_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid document ID format.")

    # Fetch document ensuring user owns it
    stmt = select(Document).where(
        Document.id == doc_uuid,
        Document.user_id == current_user.id,
    )
    res = await db.execute(stmt)
    doc = res.scalar_one_or_none()
    if not doc:
        raise HTTPException(
            status_code=404,
            detail="Document not found or you do not have permission to evaluate it.",
        )

    text_to_eval = (doc.extracted_text or "").strip()
    if not text_to_eval or len(text_to_eval) < 15:
        raise HTTPException(
            status_code=400,
            detail="Document text is empty or too short for a rigorous quality evaluation.",
        )

    # Fast Cache Check: If already evaluated and not force-refreshing, return immediately
    eval_stmt = select(NoteEvaluation).where(
        NoteEvaluation.document_id == doc.id,
        NoteEvaluation.user_id == current_user.id,
    )
    eval_res = await db.execute(eval_stmt)
    eval_record = eval_res.scalar_one_or_none()

    if eval_record and not force_refresh:
        return NoteEvaluationResponse(
            id=str(eval_record.id),
            document_id=str(eval_record.document_id),
            user_id=str(eval_record.user_id),
            topic_relevance_score=eval_record.topic_relevance_score,
            factual_accuracy_score=eval_record.factual_accuracy_score,
            content_completeness_score=eval_record.content_completeness_score,
            overall_score=eval_record.overall_score,
            quality_grade=eval_record.quality_grade,
            summary=eval_record.summary,
            flagged_claims=eval_record.flagged_claims or [],
            missing_topics=eval_record.missing_topics or [],
            verified_facts=eval_record.verified_facts or [],
            uncertain_claims=eval_record.uncertain_claims or [],
            additional_context=eval_record.additional_context or [],
            strengths=eval_record.strengths or [],
            weaknesses=eval_record.weaknesses or [],
            recommendations=eval_record.recommendations or [],
            created_at=eval_record.created_at,
            updated_at=eval_record.updated_at,
        )

    # Perform evaluation with Gemini
    result = evaluate_note_quality(
        text=text_to_eval,
        title=doc.title,
        subject=doc.subject,
    )

    if eval_record:
        # Update existing evaluation
        eval_record.topic_relevance_score = result["topic_relevance_score"]
        eval_record.factual_accuracy_score = result["factual_accuracy_score"]
        eval_record.content_completeness_score = result["content_completeness_score"]
        eval_record.overall_score = result["overall_score"]
        eval_record.quality_grade = result["quality_grade"]
        eval_record.summary = result["summary"]
        eval_record.flagged_claims = result["flagged_claims"]
        eval_record.missing_topics = result["missing_topics"]
        eval_record.verified_facts = result["verified_facts"]
        eval_record.uncertain_claims = result["uncertain_claims"]
        eval_record.additional_context = result["additional_context"]
        eval_record.strengths = result["strengths"]
        eval_record.weaknesses = result["weaknesses"]
        eval_record.recommendations = result["recommendations"]
    else:
        # Create fresh evaluation record
        eval_record = NoteEvaluation(
            id=uuid.uuid4(),
            user_id=current_user.id,
            document_id=doc.id,
            topic_relevance_score=result["topic_relevance_score"],
            factual_accuracy_score=result["factual_accuracy_score"],
            content_completeness_score=result["content_completeness_score"],
            overall_score=result["overall_score"],
            quality_grade=result["quality_grade"],
            summary=result["summary"],
            flagged_claims=result["flagged_claims"],
            missing_topics=result["missing_topics"],
            verified_facts=result["verified_facts"],
            uncertain_claims=result["uncertain_claims"],
            additional_context=result["additional_context"],
            strengths=result["strengths"],
            weaknesses=result["weaknesses"],
            recommendations=result["recommendations"],
        )
        db.add(eval_record)

    await db.commit()
    await db.refresh(eval_record)

    return NoteEvaluationResponse(
        id=str(eval_record.id),
        document_id=str(eval_record.document_id),
        user_id=str(eval_record.user_id),
        topic_relevance_score=eval_record.topic_relevance_score,
        factual_accuracy_score=eval_record.factual_accuracy_score,
        content_completeness_score=eval_record.content_completeness_score,
        overall_score=eval_record.overall_score,
        quality_grade=eval_record.quality_grade,
        summary=eval_record.summary,
        flagged_claims=eval_record.flagged_claims or [],
        missing_topics=eval_record.missing_topics or [],
        verified_facts=eval_record.verified_facts or [],
        uncertain_claims=eval_record.uncertain_claims or [],
        additional_context=eval_record.additional_context or [],
        strengths=eval_record.strengths or [],
        weaknesses=eval_record.weaknesses or [],
        recommendations=eval_record.recommendations or [],
        created_at=eval_record.created_at,
        updated_at=eval_record.updated_at,
    )


@router.get("/document/{document_id}", response_model=NoteEvaluationResponse)
async def get_document_evaluation(
    document_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Retrieves the persisted Note Quality Evaluation for a specified document.
    Returns 404 if the document has not yet been evaluated.
    """
    try:
        doc_uuid = uuid.UUID(document_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid document ID format.")

    stmt = select(NoteEvaluation).where(
        NoteEvaluation.document_id == doc_uuid,
        NoteEvaluation.user_id == current_user.id,
    )
    res = await db.execute(stmt)
    eval_record = res.scalar_one_or_none()

    if not eval_record:
        raise HTTPException(
            status_code=404,
            detail="No quality evaluation found for this document. Please run an evaluation first.",
        )

    return NoteEvaluationResponse(
        id=str(eval_record.id),
        document_id=str(eval_record.document_id),
        user_id=str(eval_record.user_id),
        topic_relevance_score=eval_record.topic_relevance_score,
        factual_accuracy_score=eval_record.factual_accuracy_score,
        content_completeness_score=eval_record.content_completeness_score,
        overall_score=eval_record.overall_score,
        quality_grade=eval_record.quality_grade,
        summary=eval_record.summary,
        flagged_claims=eval_record.flagged_claims or [],
        missing_topics=eval_record.missing_topics or [],
        verified_facts=eval_record.verified_facts or [],
        uncertain_claims=eval_record.uncertain_claims or [],
        additional_context=eval_record.additional_context or [],
        strengths=eval_record.strengths or [],
        weaknesses=eval_record.weaknesses or [],
        recommendations=eval_record.recommendations or [],
        created_at=eval_record.created_at,
        updated_at=eval_record.updated_at,
    )


@router.post("/evaluate-text", response_model=NoteEvaluationResponse)
async def evaluate_text_content(
    req: NoteEvaluationCreateRequest,
    current_user: Optional[User] = Depends(get_optional_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Evaluates raw text or an optional document_id.
    Persists evaluation in PostgreSQL when authenticated and document_id is valid.
    """
    text_to_eval = (req.text or "").strip()
    doc_uuid = None
    target_doc = None

    if req.document_id:
        try:
            doc_uuid = uuid.UUID(req.document_id)
            if current_user:
                stmt = select(Document).where(
                    Document.id == doc_uuid,
                    Document.user_id == current_user.id,
                )
                res = await db.execute(stmt)
                target_doc = res.scalar_one_or_none()
                if target_doc and not text_to_eval:
                    text_to_eval = (target_doc.extracted_text or "").strip()
        except ValueError:
            pass

    if not text_to_eval or len(text_to_eval) < 15:
        raise HTTPException(
            status_code=400,
            detail="Text is too brief for evaluation. Please provide at least a couple of sentences.",
        )

    title = req.title or (target_doc.title if target_doc else None)
    subject = req.subject or (target_doc.subject if target_doc else None)

    result = evaluate_note_quality(
        text=text_to_eval,
        title=title,
        subject=subject,
    )

    eval_id = str(uuid.uuid4())
    created_at = None
    updated_at = None

    if current_user and target_doc:
        eval_stmt = select(NoteEvaluation).where(
            NoteEvaluation.document_id == target_doc.id,
            NoteEvaluation.user_id == current_user.id,
        )
        eval_res = await db.execute(eval_stmt)
        eval_record = eval_res.scalar_one_or_none()

        if eval_record:
            eval_record.topic_relevance_score = result["topic_relevance_score"]
            eval_record.factual_accuracy_score = result["factual_accuracy_score"]
            eval_record.content_completeness_score = result["content_completeness_score"]
            eval_record.overall_score = result["overall_score"]
            eval_record.quality_grade = result["quality_grade"]
            eval_record.summary = result["summary"]
            eval_record.flagged_claims = result["flagged_claims"]
            eval_record.missing_topics = result["missing_topics"]
            eval_record.verified_facts = result["verified_facts"]
            eval_record.uncertain_claims = result["uncertain_claims"]
            eval_record.additional_context = result["additional_context"]
            eval_record.strengths = result["strengths"]
            eval_record.weaknesses = result["weaknesses"]
            eval_record.recommendations = result["recommendations"]
        else:
            eval_record = NoteEvaluation(
                id=uuid.UUID(eval_id),
                user_id=current_user.id,
                document_id=target_doc.id,
                topic_relevance_score=result["topic_relevance_score"],
                factual_accuracy_score=result["factual_accuracy_score"],
                content_completeness_score=result["content_completeness_score"],
                overall_score=result["overall_score"],
                quality_grade=result["quality_grade"],
                summary=result["summary"],
                flagged_claims=result["flagged_claims"],
                missing_topics=result["missing_topics"],
                verified_facts=result["verified_facts"],
                uncertain_claims=result["uncertain_claims"],
                additional_context=result["additional_context"],
                strengths=result["strengths"],
                weaknesses=result["weaknesses"],
                recommendations=result["recommendations"],
            )
            db.add(eval_record)

        await db.commit()
        await db.refresh(eval_record)
        eval_id = str(eval_record.id)
        created_at = eval_record.created_at
        updated_at = eval_record.updated_at

    return NoteEvaluationResponse(
        id=eval_id,
        document_id=str(target_doc.id) if target_doc else None,
        user_id=str(current_user.id) if current_user else None,
        topic_relevance_score=result["topic_relevance_score"],
        factual_accuracy_score=result["factual_accuracy_score"],
        content_completeness_score=result["content_completeness_score"],
        overall_score=result["overall_score"],
        quality_grade=result["quality_grade"],
        summary=result["summary"],
        flagged_claims=result["flagged_claims"],
        missing_topics=result["missing_topics"],
        verified_facts=result["verified_facts"],
        uncertain_claims=result["uncertain_claims"],
        additional_context=result["additional_context"],
        strengths=result["strengths"],
        weaknesses=result["weaknesses"],
        recommendations=result["recommendations"],
        created_at=created_at,
        updated_at=updated_at,
    )

