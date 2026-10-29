from datetime import datetime, timezone
import logging
from typing import List, Optional
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from ..auth import get_current_user, get_optional_current_user
from ..database import get_db
from ..db_models import ChatMessage, Conversation, Document, User
from ..gemini_service import answer_student_chat, answer_student_tutor_chat
from ..models import (
    ChatMessageItem,
    ChatMessageSendRequest,
    ChatRequest,
    ChatResponse,
    ConversationCreateRequest,
    ConversationResponse,
    ConversationSummaryResponse,
    HistoryMessage,
    MessageResponse,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/chat", tags=["Chat & AI Tutor"])


# =============================================================================
# CONVERSATION MANAGEMENT
# =============================================================================

@router.get("/conversations", response_model=List[ConversationSummaryResponse])
async def list_conversations(
    document_id: Optional[str] = Query(None, description="Filter by study document UUID"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Lists all AI Tutor conversations belonging to the authenticated student,
    optionally filtered by document, ordered by most recently active.
    """
    stmt = (
        select(Conversation)
        .where(Conversation.user_id == current_user.id)
        .options(selectinload(Conversation.messages))
        .order_by(Conversation.updated_at.desc())
    )

    if document_id:
        try:
            doc_uuid = uuid.UUID(document_id)
            stmt = stmt.where(Conversation.document_id == doc_uuid)
        except (ValueError, TypeError):
            return []

    result = await db.execute(stmt)
    conversations = result.scalars().all()

    summaries = []
    for conv in conversations:
        msg_count = len(conv.messages)
        last_msg = conv.messages[-1].text if conv.messages else None
        summaries.append(
            ConversationSummaryResponse(
                id=str(conv.id),
                document_id=str(conv.document_id) if conv.document_id else None,
                title=conv.title,
                message_count=msg_count,
                last_message=last_msg,
                created_at=conv.created_at,
                updated_at=conv.updated_at,
            )
        )
    return summaries


@router.post("/conversations", response_model=ConversationResponse, status_code=status.HTTP_201_CREATED)
async def create_conversation(
    req: ConversationCreateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Creates a new learning conversation for the student, optionally associated with a document.
    """
    doc_uuid = None
    default_title = req.title or "General Study Chat"

    if req.document_id:
        try:
            doc_uuid = uuid.UUID(req.document_id)
            # Verify student owns this document
            doc_stmt = select(Document).where(
                Document.id == doc_uuid,
                Document.user_id == current_user.id,
            )
            doc_res = await db.execute(doc_stmt)
            doc = doc_res.scalar_one_or_none()
            if not doc:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Specified study document not found or does not belong to you.",
                )
            if not req.title:
                default_title = f"Chat: {doc.title}"
        except (ValueError, TypeError):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid document_id format.",
            )

    conv = Conversation(
        id=uuid.uuid4(),
        user_id=current_user.id,
        document_id=doc_uuid,
        title=default_title[:255],
    )
    db.add(conv)
    await db.commit()
    await db.refresh(conv)

    return ConversationResponse(
        id=str(conv.id),
        user_id=str(conv.user_id),
        document_id=str(conv.document_id) if conv.document_id else None,
        title=conv.title,
        created_at=conv.created_at,
        updated_at=conv.updated_at,
        messages=[],
    )


@router.get("/conversations/{conversation_id}", response_model=ConversationResponse)
async def get_conversation(
    conversation_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Retrieves an existing conversation and its complete message history.
    Enforces student authorization.
    """
    try:
        conv_uuid = uuid.UUID(conversation_id)
    except (ValueError, TypeError):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid conversation_id.")

    stmt = (
        select(Conversation)
        .where(
            Conversation.id == conv_uuid,
            Conversation.user_id == current_user.id,
        )
        .options(selectinload(Conversation.messages))
    )
    result = await db.execute(stmt)
    conv = result.scalar_one_or_none()

    if not conv:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found or access denied.",
        )

    msg_items = [
        ChatMessageItem(
            id=str(m.id),
            conversation_id=str(m.conversation_id),
            sender=m.sender,
            text=m.text,
            note_reference=m.note_reference,
            key_takeaways=m.key_takeaways or [],
            outside_context=m.outside_context,
            created_at=m.created_at,
        )
        for m in conv.messages
    ]

    return ConversationResponse(
        id=str(conv.id),
        user_id=str(conv.user_id),
        document_id=str(conv.document_id) if conv.document_id else None,
        title=conv.title,
        created_at=conv.created_at,
        updated_at=conv.updated_at,
        messages=msg_items,
    )


@router.delete("/conversations/{conversation_id}", response_model=MessageResponse)
async def delete_conversation(
    conversation_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Deletes an AI Tutor conversation and all associated message history.
    """
    try:
        conv_uuid = uuid.UUID(conversation_id)
    except (ValueError, TypeError):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid conversation_id.")

    stmt = select(Conversation).where(
        Conversation.id == conv_uuid,
        Conversation.user_id == current_user.id,
    )
    result = await db.execute(stmt)
    conv = result.scalar_one_or_none()

    if not conv:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found or access denied.",
        )

    await db.delete(conv)
    await db.commit()
    return MessageResponse(message="Conversation deleted successfully.")


# =============================================================================
# CHAT MESSAGING & AI TUTOR INTERACTION
# =============================================================================

@router.post("/conversations/{conversation_id}/messages", response_model=ChatMessageItem, status_code=status.HTTP_201_CREATED)
async def send_message_in_conversation(
    conversation_id: str,
    req: ChatMessageSendRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Sends a student message into an existing conversation, runs AI Tutor reasoning
    with relevant document chunk retrieval, persists user & AI messages in PostgreSQL,
    and returns the AI Tutor response.
    """
    clean_msg = req.message.strip()
    if not clean_msg:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Message cannot be empty.")

    try:
        conv_uuid = uuid.UUID(conversation_id)
    except (ValueError, TypeError):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid conversation_id.")

    # 1. Fetch conversation and verify ownership
    conv_stmt = (
        select(Conversation)
        .where(
            Conversation.id == conv_uuid,
            Conversation.user_id == current_user.id,
        )
        .options(selectinload(Conversation.messages))
    )
    conv_res = await db.execute(conv_stmt)
    conv = conv_res.scalar_one_or_none()

    if not conv:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found or access denied.",
        )

    # 2. Retrieve document context if conversation is linked to a document
    doc_text = ""
    doc_title = None
    doc_subject = None
    if conv.document_id:
        doc_stmt = select(Document).where(
            Document.id == conv.document_id,
            Document.user_id == current_user.id,
        )
        doc_res = await db.execute(doc_stmt)
        doc = doc_res.scalar_one_or_none()
        if doc:
            doc_text = doc.extracted_text or ""
            doc_title = doc.title
            doc_subject = doc.subject

    # 3. Build history from recent messages explicitly via async query (avoiding greenlet lazy-loading)
    msg_stmt = (
        select(ChatMessage)
        .where(ChatMessage.conversation_id == conv.id)
        .order_by(ChatMessage.created_at.asc())
    )
    msg_res = await db.execute(msg_stmt)
    history_db_messages = msg_res.scalars().all()

    history_messages = [
        HistoryMessage(role="user" if m.sender == "user" else "model", content=m.text)
        for m in history_db_messages[-8:]
    ]

    # 4. Save User Message
    user_msg = ChatMessage(
        id=uuid.uuid4(),
        conversation_id=conv.id,
        sender="user",
        text=clean_msg,
    )
    db.add(user_msg)

    # 5. Call Gemini AI Tutor with relevant chunk retrieval and broader context support
    tutor_reply = answer_student_tutor_chat(
        message=clean_msg,
        document_context=doc_text,
        history=history_messages,
        document_title=doc_title,
        subject=doc_subject,
    )

    # 6. Save AI Response Message
    outside_str = "true" if tutor_reply.get("outside_knowledge_used") else "false"
    ai_msg = ChatMessage(
        id=uuid.uuid4(),
        conversation_id=conv.id,
        sender="ai",
        text=tutor_reply["reply"],
        note_reference=tutor_reply.get("note_reference"),
        key_takeaways=tutor_reply.get("key_takeaways") or [],
        outside_context=outside_str,
    )
    db.add(ai_msg)

    # 7. Update conversation updated_at and title if first message
    conv.updated_at = datetime.now(timezone.utc)
    if conv.title == "General Study Chat" and not conv.document_id:
        # Title from first message (first 6 words)
        words = clean_msg.split()
        if words:
            short_title = " ".join(words[:6])
            conv.title = f"Chat: {short_title}"

    await db.commit()
    await db.refresh(ai_msg)

    return ChatMessageItem(
        id=str(ai_msg.id),
        conversation_id=str(ai_msg.conversation_id),
        sender=ai_msg.sender,
        text=ai_msg.text,
        note_reference=ai_msg.note_reference,
        key_takeaways=ai_msg.key_takeaways or [],
        outside_context=ai_msg.outside_context,
        created_at=ai_msg.created_at,
    )


@router.post("/message", response_model=ChatResponse)
async def send_chat_message(
    req: ChatMessageSendRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Unified chat endpoint for Flutter app.
    Automatically finds or creates an active conversation for the given document or general study session,
    processes the query with AI Tutor reasoning, persists both turns to PostgreSQL, and returns ChatResponse.
    """
    clean_msg = req.message.strip()
    if not clean_msg:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Message cannot be empty.")

    conv = None

    # Case A: explicit conversation_id passed
    if req.conversation_id:
        try:
            conv_uuid = uuid.UUID(req.conversation_id)
            c_stmt = (
                select(Conversation)
                .where(Conversation.id == conv_uuid, Conversation.user_id == current_user.id)
                .options(selectinload(Conversation.messages))
            )
            c_res = await db.execute(c_stmt)
            conv = c_res.scalar_one_or_none()
        except (ValueError, TypeError):
            pass

    # Case B: document_id passed, find or create active conversation for that document
    if not conv and req.document_id:
        try:
            doc_uuid = uuid.UUID(req.document_id)
            doc_stmt = select(Document).where(
                Document.id == doc_uuid,
                Document.user_id == current_user.id,
            )
            doc_res = await db.execute(doc_stmt)
            doc = doc_res.scalar_one_or_none()
            if doc:
                # Find most recent conversation for this document
                c_stmt = (
                    select(Conversation)
                    .where(Conversation.document_id == doc_uuid, Conversation.user_id == current_user.id)
                    .options(selectinload(Conversation.messages))
                    .order_by(Conversation.updated_at.desc())
                )
                c_res = await db.execute(c_stmt)
                conv = c_res.scalars().first()

                if not conv:
                    conv = Conversation(
                        id=uuid.uuid4(),
                        user_id=current_user.id,
                        document_id=doc_uuid,
                        title=f"Chat: {doc.title}"[:255],
                    )
                    db.add(conv)
                    await db.flush()
        except (ValueError, TypeError):
            pass

    # Case C: General conversation (no document or document not found)
    if not conv:
        # Find latest general conversation (document_id is None)
        c_stmt = (
            select(Conversation)
            .where(Conversation.document_id.is_(None), Conversation.user_id == current_user.id)
            .options(selectinload(Conversation.messages))
            .order_by(Conversation.updated_at.desc())
        )
        c_res = await db.execute(c_stmt)
        conv = c_res.scalars().first()

        if not conv:
            conv = Conversation(
                id=uuid.uuid4(),
                user_id=current_user.id,
                document_id=None,
                title="General Study Chat",
            )
            db.add(conv)
            await db.flush()

    # Retrieve document text if available
    doc_text = ""
    doc_title = None
    doc_subject = None
    if conv.document_id:
        d_stmt = select(Document).where(Document.id == conv.document_id, Document.user_id == current_user.id)
        d_res = await db.execute(d_stmt)
        doc = d_res.scalar_one_or_none()
        if doc:
            doc_text = doc.extracted_text or ""
            doc_title = doc.title
            doc_subject = doc.subject

    # Recent history via explicit async query (avoiding greenlet lazy-loading)
    msg_stmt = (
        select(ChatMessage)
        .where(ChatMessage.conversation_id == conv.id)
        .order_by(ChatMessage.created_at.asc())
    )
    msg_res = await db.execute(msg_stmt)
    messages_list = msg_res.scalars().all()

    history_messages = [
        HistoryMessage(role="user" if m.sender == "user" else "model", content=m.text)
        for m in messages_list[-8:]
    ]

    # Save User message
    user_msg = ChatMessage(
        id=uuid.uuid4(),
        conversation_id=conv.id,
        sender="user",
        text=clean_msg,
    )
    db.add(user_msg)

    # Run AI Tutor
    tutor_reply = answer_student_tutor_chat(
        message=clean_msg,
        document_context=doc_text,
        history=history_messages,
        document_title=doc_title,
        subject=doc_subject,
    )

    # Save AI message
    outside_str = "true" if tutor_reply.get("outside_knowledge_used") else "false"
    ai_msg = ChatMessage(
        id=uuid.uuid4(),
        conversation_id=conv.id,
        sender="ai",
        text=tutor_reply["reply"],
        note_reference=tutor_reply.get("note_reference"),
        key_takeaways=tutor_reply.get("key_takeaways") or [],
        outside_context=outside_str,
    )
    db.add(ai_msg)

    conv.updated_at = datetime.now(timezone.utc)
    if conv.title == "General Study Chat" and not conv.document_id and len(messages_list) == 0:
        words = clean_msg.split()
        if words:
            conv.title = f"Chat: {' '.join(words[:6])}"[:255]

    final_conv_id = str(conv.id)
    await db.commit()
    await db.refresh(ai_msg)

    return ChatResponse(
        reply=ai_msg.text,
        note_reference=ai_msg.note_reference,
        key_takeaways=ai_msg.key_takeaways or [],
        outside_knowledge_used=tutor_reply.get("outside_knowledge_used", False),
        conversation_id=final_conv_id,
        message_id=str(ai_msg.id),
    )


# =============================================================================
# LEGACY / BACKWARDS-COMPATIBLE ENDPOINT
# =============================================================================

@router.post("", response_model=ChatResponse)
async def chat_with_notes_legacy(
    req: ChatRequest,
    current_user: Optional[User] = Depends(get_optional_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Backwards-compatible chat endpoint.
    If authenticated, connects and persists into PostgreSQL conversations.
    If unauthenticated, answers directly via Gemini.
    """
    cleaned_msg = req.message.strip()
    if not cleaned_msg:
        raise HTTPException(status_code=400, detail="Chat message cannot be empty.")

    if current_user:
        send_req = ChatMessageSendRequest(
            message=cleaned_msg,
            conversation_id=req.conversation_id,
            document_id=req.document_id,
        )
        return await send_chat_message(req=send_req, current_user=current_user, db=db)

    # Fallback for unauthenticated legacy calls / unit tests
    return answer_student_chat(
        message=cleaned_msg,
        note_context=req.note_context or "",
        history=req.history or [],
    )
