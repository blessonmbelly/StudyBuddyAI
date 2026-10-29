from typing import List, Optional
import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..auth import get_current_user, get_optional_current_user
from ..database import get_db
from ..db_models import Document, GeneratedNote, User
from ..gemini_service import generate_study_notes
from ..models import (
    MessageResponse,
    NoteGenerateRequest,
    NoteGenerateResponse,
    NoteResponse,
)

router = APIRouter(prefix="/api/notes", tags=["Notes"])


@router.post("/generate", response_model=NoteGenerateResponse)
async def generate_notes(
    req: NoteGenerateRequest,
    current_user: Optional[User] = Depends(get_optional_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Generates a structured short note deck from raw extracted or pasted text.
    Includes title, summary, key definitions, and exam pitfalls.
    When invoked by an authenticated user, persists the note in PostgreSQL.
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

    note_id = "1"
    if current_user:
        try:
            doc_uuid = None
            if req.document_id:
                try:
                    doc_uuid = uuid.UUID(req.document_id)
                except (ValueError, TypeError):
                    doc_uuid = None

            # Serialize section and bullet objects for JSONB storage
            sections_data = [
                {
                    "title": s.title,
                    "description": s.description,
                    "bullets": [
                        {"term": b.term, "definition": b.definition, "icon_name": b.icon_name}
                        for b in s.bullets
                    ],
                }
                for s in notes.sections
            ]
            key_defs_data = [
                {"title": d.title, "tag": d.tag, "body": d.body}
                for d in notes.key_definitions
            ]
            pitfalls_data = [
                {
                    "title": p.title,
                    "description": p.description,
                    "concept_a": p.concept_a,
                    "concept_b": p.concept_b,
                }
                for p in notes.exam_pitfalls
            ]

            db_note = GeneratedNote(
                id=uuid.uuid4(),
                user_id=current_user.id,
                document_id=doc_uuid,
                title=notes.title,
                course_name=notes.course_name,
                course_code=notes.course_code,
                summary=notes.summary,
                sections=sections_data,
                key_definitions=key_defs_data,
                exam_pitfalls=pitfalls_data,
                raw_transcript=notes.raw_transcript,
                accuracy_percent=notes.accuracy_percent,
                key_terms_count=notes.key_terms_count,
                read_time=notes.read_time,
            )
            db.add(db_note)
            await db.commit()
            await db.refresh(db_note)
            note_id = str(db_note.id)
            notes.id = note_id
            notes.document_id = str(doc_uuid) if doc_uuid else None
        except Exception:
            await db.rollback()

    return notes


@router.get("", response_model=List[NoteResponse])
async def list_notes(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Lists all saved study notes belonging to the authenticated student.
    """
    stmt = (
        select(GeneratedNote)
        .where(GeneratedNote.user_id == current_user.id)
        .order_by(GeneratedNote.created_at.desc())
    )
    result = await db.execute(stmt)
    notes = result.scalars().all()

    return [
        NoteResponse(
            id=str(n.id),
            title=n.title,
            course_name=n.course_name,
            course_code=n.course_code,
            summary=n.summary,
            sections=n.sections or [],
            key_definitions=n.key_definitions or [],
            exam_pitfalls=n.exam_pitfalls or [],
            raw_transcript=n.raw_transcript,
            accuracy_percent=n.accuracy_percent,
            key_terms_count=n.key_terms_count,
            read_time=n.read_time,
            document_id=str(n.document_id) if n.document_id else None,
            created_at=n.created_at,
        )
        for n in notes
    ]


@router.get("/{note_id}", response_model=NoteResponse)
async def get_note(
    note_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Retrieves a single note by ID, enforcing user isolation.
    """
    try:
        note_uuid = uuid.UUID(note_id)
    except (ValueError, TypeError):
        raise HTTPException(status_code=400, detail="Invalid note ID format.")

    stmt = select(GeneratedNote).where(
        GeneratedNote.id == note_uuid, GeneratedNote.user_id == current_user.id
    )
    result = await db.execute(stmt)
    note = result.scalar_one_or_none()

    if not note:
        raise HTTPException(status_code=404, detail="Note not found.")

    return NoteResponse(
        id=str(note.id),
        title=note.title,
        course_name=note.course_name,
        course_code=note.course_code,
        summary=note.summary,
        sections=note.sections or [],
        key_definitions=note.key_definitions or [],
        exam_pitfalls=note.exam_pitfalls or [],
        raw_transcript=note.raw_transcript,
        accuracy_percent=note.accuracy_percent,
        key_terms_count=note.key_terms_count,
        read_time=note.read_time,
        document_id=str(note.document_id) if note.document_id else None,
        created_at=note.created_at,
    )


@router.delete("/{note_id}", response_model=MessageResponse)
async def delete_note(
    note_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Deletes a saved note, enforcing user ownership.
    """
    try:
        note_uuid = uuid.UUID(note_id)
    except (ValueError, TypeError):
        raise HTTPException(status_code=400, detail="Invalid note ID format.")

    stmt = select(GeneratedNote).where(
        GeneratedNote.id == note_uuid, GeneratedNote.user_id == current_user.id
    )
    result = await db.execute(stmt)
    note = result.scalar_one_or_none()

    if not note:
        raise HTTPException(status_code=404, detail="Note not found.")

    await db.delete(note)
    await db.commit()

    return MessageResponse(message="Note deleted successfully.")
