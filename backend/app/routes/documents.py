import logging
from typing import List
import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from ..auth import get_current_user
from ..database import get_db
from ..db_models import Document, GeneratedNote, Quiz, User
from ..models import (
    DocumentCreateRequest,
    DocumentResponse,
    DocumentUpdateRequest,
    MessageResponse,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/documents", tags=["Documents"])


@router.get("", response_model=List[DocumentResponse])
async def list_documents(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Retrieves all study documents belonging to the authenticated student,
    ordered by most recent creation date.
    """
    stmt = (
        select(Document)
        .where(Document.user_id == current_user.id)
        .options(
            selectinload(Document.generated_notes),
            selectinload(Document.quizzes),
        )
        .order_by(Document.created_at.desc())
    )
    result = await db.execute(stmt)
    docs = result.scalars().all()

    res_list = []
    for doc in docs:
        latest_note = doc.generated_notes[0] if doc.generated_notes else None
        latest_note_dict = None
        if latest_note:
            latest_note_dict = {
                "id": str(latest_note.id),
                "title": latest_note.title,
                "course_name": latest_note.course_name,
                "course_code": latest_note.course_code,
                "summary": latest_note.summary,
                "sections": latest_note.sections or [],
                "key_definitions": latest_note.key_definitions or [],
                "exam_pitfalls": latest_note.exam_pitfalls or [],
                "raw_transcript": latest_note.raw_transcript,
                "accuracy_percent": latest_note.accuracy_percent,
                "key_terms_count": latest_note.key_terms_count,
                "read_time": latest_note.read_time,
            }

        latest_quiz_list = None
        if doc.quizzes:
            latest_quiz_list = doc.quizzes[0].questions

        res_list.append(
            DocumentResponse(
                id=str(doc.id),
                title=doc.title,
                original_filename=doc.original_filename,
                file_type=doc.file_type,
                subject=doc.subject,
                topics=doc.topics or [],
                extracted_text=doc.extracted_text,
                word_count=doc.word_count,
                page_count=doc.page_count,
                extraction_method=doc.extraction_method,
                processing_status=doc.processing_status,
                created_at=doc.created_at,
                generated_note=latest_note_dict,
                generated_quiz=latest_quiz_list,
            )
        )
    return res_list


@router.post("", response_model=DocumentResponse, status_code=status.HTTP_201_CREATED)
async def create_document(
    req: DocumentCreateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Creates and persists a new study document for the authenticated student.
    """
    words = req.word_count or len(req.extracted_text.split())
    new_doc = Document(
        id=uuid.uuid4(),
        user_id=current_user.id,
        title=req.title,
        original_filename=req.original_filename or "document",
        file_type=req.file_type or "TXT",
        subject=req.subject or "General",
        topics=req.topics or [],
        extracted_text=req.extracted_text,
        word_count=words,
        page_count=req.page_count or 1,
        extraction_method=req.extraction_method or "pasted_text",
        processing_status=req.processing_status or "completed",
    )
    db.add(new_doc)
    await db.commit()
    await db.refresh(new_doc)

    return DocumentResponse(
        id=str(new_doc.id),
        title=new_doc.title,
        original_filename=new_doc.original_filename,
        file_type=new_doc.file_type,
        subject=new_doc.subject,
        topics=new_doc.topics or [],
        extracted_text=new_doc.extracted_text,
        word_count=new_doc.word_count,
        page_count=new_doc.page_count,
        extraction_method=new_doc.extraction_method,
        processing_status=new_doc.processing_status,
        created_at=new_doc.created_at,
        generated_note=None,
        generated_quiz=None,
    )


@router.get("/{document_id}", response_model=DocumentResponse)
async def get_document(
    document_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Retrieves a single study document by ID, enforcing per-user data isolation.
    """
    try:
        doc_uuid = uuid.UUID(document_id)
    except (ValueError, TypeError):
        raise HTTPException(status_code=400, detail="Invalid document ID format.")

    stmt = (
        select(Document)
        .where(Document.id == doc_uuid, Document.user_id == current_user.id)
        .options(
            selectinload(Document.generated_notes),
            selectinload(Document.quizzes),
        )
    )
    result = await db.execute(stmt)
    doc = result.scalar_one_or_none()

    if not doc:
        raise HTTPException(status_code=404, detail="Document not found.")

    latest_note = doc.generated_notes[0] if doc.generated_notes else None
    latest_note_dict = None
    if latest_note:
        latest_note_dict = {
            "id": str(latest_note.id),
            "title": latest_note.title,
            "course_name": latest_note.course_name,
            "course_code": latest_note.course_code,
            "summary": latest_note.summary,
            "sections": latest_note.sections or [],
            "key_definitions": latest_note.key_definitions or [],
            "exam_pitfalls": latest_note.exam_pitfalls or [],
            "raw_transcript": latest_note.raw_transcript,
            "accuracy_percent": latest_note.accuracy_percent,
            "key_terms_count": latest_note.key_terms_count,
            "read_time": latest_note.read_time,
        }

    latest_quiz_list = doc.quizzes[0].questions if doc.quizzes else None

    return DocumentResponse(
        id=str(doc.id),
        title=doc.title,
        original_filename=doc.original_filename,
        file_type=doc.file_type,
        subject=doc.subject,
        topics=doc.topics or [],
        extracted_text=doc.extracted_text,
        word_count=doc.word_count,
        page_count=doc.page_count,
        extraction_method=doc.extraction_method,
        processing_status=doc.processing_status,
        created_at=doc.created_at,
        generated_note=latest_note_dict,
        generated_quiz=latest_quiz_list,
    )


@router.put("/{document_id}", response_model=DocumentResponse)
async def update_document(
    document_id: str,
    req: DocumentUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Updates document metadata (title, subject, topics), enforcing user ownership.
    """
    try:
        doc_uuid = uuid.UUID(document_id)
    except (ValueError, TypeError):
        raise HTTPException(status_code=400, detail="Invalid document ID format.")

    stmt = select(Document).where(Document.id == doc_uuid, Document.user_id == current_user.id)
    result = await db.execute(stmt)
    doc = result.scalar_one_or_none()

    if not doc:
        raise HTTPException(status_code=404, detail="Document not found.")

    if req.title is not None and req.title.strip():
        doc.title = req.title.strip()
    if req.subject is not None and req.subject.strip():
        doc.subject = req.subject.strip()
    if req.topics is not None:
        doc.topics = req.topics

    doc.processing_status = "edited"
    await db.commit()
    await db.refresh(doc)

    return DocumentResponse(
        id=str(doc.id),
        title=doc.title,
        original_filename=doc.original_filename,
        file_type=doc.file_type,
        subject=doc.subject,
        topics=doc.topics or [],
        extracted_text=doc.extracted_text,
        word_count=doc.word_count,
        page_count=doc.page_count,
        extraction_method=doc.extraction_method,
        processing_status=doc.processing_status,
        created_at=doc.created_at,
    )


@router.delete("/{document_id}", response_model=MessageResponse)
async def delete_document(
    document_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Permanently deletes a document and all cascading notes, quizzes, and attempts.
    """
    try:
        doc_uuid = uuid.UUID(document_id)
    except (ValueError, TypeError):
        raise HTTPException(status_code=400, detail="Invalid document ID format.")

    stmt = select(Document).where(Document.id == doc_uuid, Document.user_id == current_user.id)
    result = await db.execute(stmt)
    doc = result.scalar_one_or_none()

    if not doc:
        raise HTTPException(status_code=404, detail="Document not found.")

    await db.delete(doc)
    await db.commit()

    return MessageResponse(message="Document deleted successfully.")

