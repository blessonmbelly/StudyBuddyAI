from datetime import datetime, timezone
import logging
from typing import List, Optional
import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from ..auth import get_current_user
from ..database import get_db
from ..db_models import Flashcard, FlashcardDeck, FlashcardReview, User
from ..gemini_service import generate_flashcards
from ..models import (
    CardReviewItem,
    FlashcardCreateRequest,
    FlashcardDeckResponse,
    FlashcardGenerateRequest,
    FlashcardItem,
    FlashcardReviewRequest,
    FlashcardReviewResponse,
    FlashcardStatusUpdateRequest,
    MessageResponse,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/flashcards", tags=["Flashcards"])


@router.post("/generate", response_model=FlashcardDeckResponse, status_code=status.HTTP_201_CREATED)
async def generate_and_save_flashcards(
    req: FlashcardGenerateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Generates Q&A flashcards using Gemini AI grounded strictly in the student's study text,
    persisting the deck and individual cards directly to PostgreSQL.
    """
    cleaned_text = req.text.strip()
    if not cleaned_text:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot generate flashcards from empty text.",
        )

    if len(cleaned_text) < 15:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Source material is too short to generate flashcards. Please provide at least a couple of sentences.",
        )

    num_cards = req.num_cards if (3 <= req.num_cards <= 20) else 6
    generated = generate_flashcards(
        text=cleaned_text,
        num_cards=num_cards,
        deck_title=req.deck_title,
        subject=req.subject,
    )

    doc_uuid = None
    if req.document_id:
        try:
            doc_uuid = uuid.UUID(req.document_id)
        except (ValueError, TypeError):
            doc_uuid = None

    note_uuid = None
    if req.note_id:
        try:
            note_uuid = uuid.UUID(req.note_id)
        except (ValueError, TypeError):
            note_uuid = None

    raw_cards = generated.get("cards", [])
    deck_id = uuid.uuid4()

    new_deck = FlashcardDeck(
        id=deck_id,
        user_id=current_user.id,
        document_id=doc_uuid,
        note_id=note_uuid,
        title=generated["title"],
        subject=generated["subject"],
        description=generated["description"],
        card_count=len(raw_cards),
        mastered_count=0,
    )
    db.add(new_deck)
    await db.flush()

    card_items: List[FlashcardItem] = []
    for i, c in enumerate(raw_cards):
        card_id = uuid.uuid4()
        card_entity = Flashcard(
            id=card_id,
            deck_id=deck_id,
            front=c["front"],
            back=c["back"],
            hint=c.get("hint"),
            order_index=i,
            status="unreviewed",
            review_count=0,
        )
        db.add(card_entity)
        card_items.append(
            FlashcardItem(
                id=str(card_id),
                front=c["front"],
                back=c["back"],
                hint=c.get("hint"),
                order_index=i,
                status="unreviewed",
                review_count=0,
            )
        )

    await db.commit()
    await db.refresh(new_deck)

    return FlashcardDeckResponse(
        id=str(new_deck.id),
        title=new_deck.title,
        subject=new_deck.subject,
        description=new_deck.description,
        card_count=new_deck.card_count,
        mastered_count=new_deck.mastered_count,
        cards=card_items,
        document_id=str(new_deck.document_id) if new_deck.document_id else None,
        note_id=str(new_deck.note_id) if new_deck.note_id else None,
        created_at=new_deck.created_at,
        updated_at=new_deck.updated_at,
    )


@router.get("/decks", response_model=List[FlashcardDeckResponse])
async def list_decks(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Retrieves all flashcard decks owned by the authenticated student,
    including their cards and mastery metrics.
    """
    stmt = (
        select(FlashcardDeck)
        .where(FlashcardDeck.user_id == current_user.id)
        .options(selectinload(FlashcardDeck.cards))
        .order_by(FlashcardDeck.created_at.desc())
    )
    result = await db.execute(stmt)
    decks = result.scalars().all()

    response_list: List[FlashcardDeckResponse] = []
    for d in decks:
        cards_list = [
            FlashcardItem(
                id=str(c.id),
                front=c.front,
                back=c.back,
                hint=c.hint,
                order_index=c.order_index,
                status=c.status,
                review_count=c.review_count,
                last_reviewed_at=c.last_reviewed_at,
            )
            for c in d.cards
        ]
        response_list.append(
            FlashcardDeckResponse(
                id=str(d.id),
                title=d.title,
                subject=d.subject,
                description=d.description,
                card_count=d.card_count,
                mastered_count=d.mastered_count,
                cards=cards_list,
                document_id=str(d.document_id) if d.document_id else None,
                note_id=str(d.note_id) if d.note_id else None,
                created_at=d.created_at,
                updated_at=d.updated_at,
            )
        )
    return response_list


@router.get("/decks/{deck_id}", response_model=FlashcardDeckResponse)
async def get_deck(
    deck_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Retrieves a single flashcard deck by ID, verifying per-user authorization.
    """
    try:
        deck_uuid = uuid.UUID(deck_id)
    except (ValueError, TypeError):
        raise HTTPException(status_code=400, detail="Invalid deck ID format.")

    stmt = (
        select(FlashcardDeck)
        .where(FlashcardDeck.id == deck_uuid, FlashcardDeck.user_id == current_user.id)
        .options(selectinload(FlashcardDeck.cards))
    )
    result = await db.execute(stmt)
    deck = result.scalar_one_or_none()

    if not deck:
        raise HTTPException(status_code=404, detail="Flashcard deck not found.")

    cards_list = [
        FlashcardItem(
            id=str(c.id),
            front=c.front,
            back=c.back,
            hint=c.hint,
            order_index=c.order_index,
            status=c.status,
            review_count=c.review_count,
            last_reviewed_at=c.last_reviewed_at,
        )
        for c in deck.cards
    ]

    return FlashcardDeckResponse(
        id=str(deck.id),
        title=deck.title,
        subject=deck.subject,
        description=deck.description,
        card_count=deck.card_count,
        mastered_count=deck.mastered_count,
        cards=cards_list,
        document_id=str(deck.document_id) if deck.document_id else None,
        note_id=str(deck.note_id) if deck.note_id else None,
        created_at=deck.created_at,
        updated_at=deck.updated_at,
    )


@router.delete("/decks/{deck_id}", response_model=MessageResponse)
async def delete_deck(
    deck_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Deletes a flashcard deck and cascades deletion to all cards and review logs.
    """
    try:
        deck_uuid = uuid.UUID(deck_id)
    except (ValueError, TypeError):
        raise HTTPException(status_code=400, detail="Invalid deck ID format.")

    stmt = select(FlashcardDeck).where(
        FlashcardDeck.id == deck_uuid, FlashcardDeck.user_id == current_user.id
    )
    result = await db.execute(stmt)
    deck = result.scalar_one_or_none()

    if not deck:
        raise HTTPException(status_code=404, detail="Flashcard deck not found.")

    await db.delete(deck)
    await db.commit()

    return MessageResponse(message="Flashcard deck deleted successfully.")


@router.post("/decks/{deck_id}/cards", response_model=FlashcardItem, status_code=status.HTTP_201_CREATED)
async def add_custom_card(
    deck_id: str,
    req: FlashcardCreateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Adds a custom flashcard to an existing deck.
    """
    try:
        deck_uuid = uuid.UUID(deck_id)
    except (ValueError, TypeError):
        raise HTTPException(status_code=400, detail="Invalid deck ID format.")

    stmt = select(FlashcardDeck).where(
        FlashcardDeck.id == deck_uuid, FlashcardDeck.user_id == current_user.id
    )
    result = await db.execute(stmt)
    deck = result.scalar_one_or_none()

    if not deck:
        raise HTTPException(status_code=404, detail="Flashcard deck not found.")

    card_id = uuid.uuid4()
    new_card = Flashcard(
        id=card_id,
        deck_id=deck.id,
        front=req.front.strip(),
        back=req.back.strip(),
        hint=req.hint.strip() if req.hint else None,
        order_index=deck.card_count,
        status="unreviewed",
        review_count=0,
    )
    db.add(new_card)

    deck.card_count += 1
    await db.commit()
    await db.refresh(new_card)

    return FlashcardItem(
        id=str(new_card.id),
        front=new_card.front,
        back=new_card.back,
        hint=new_card.hint,
        order_index=new_card.order_index,
        status=new_card.status,
        review_count=new_card.review_count,
        last_reviewed_at=new_card.last_reviewed_at,
    )


@router.put("/cards/{card_id}/status", response_model=FlashcardItem)
async def update_card_status(
    card_id: str,
    req: FlashcardStatusUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Quick status update for an individual card during review ('known' or 'learning').
    Recalculates the deck's mastered count.
    """
    try:
        c_uuid = uuid.UUID(card_id)
    except (ValueError, TypeError):
        raise HTTPException(status_code=400, detail="Invalid card ID format.")

    stmt = (
        select(Flashcard)
        .join(FlashcardDeck)
        .where(Flashcard.id == c_uuid, FlashcardDeck.user_id == current_user.id)
    )
    result = await db.execute(stmt)
    card = result.scalar_one_or_none()

    if not card:
        raise HTTPException(status_code=404, detail="Card not found.")

    card.status = req.status
    card.review_count += 1
    card.last_reviewed_at = datetime.now(timezone.utc)
    await db.flush()

    # Recalculate mastered_count for the deck
    count_stmt = (
        select(func.count(Flashcard.id))
        .where(Flashcard.deck_id == card.deck_id, Flashcard.status == "known")
    )
    known_res = await db.execute(count_stmt)
    mastered_total = known_res.scalar() or 0

    deck_stmt = select(FlashcardDeck).where(FlashcardDeck.id == card.deck_id)
    deck_res = await db.execute(deck_stmt)
    deck = deck_res.scalar_one_or_none()
    if deck:
        deck.mastered_count = mastered_total

    await db.commit()
    await db.refresh(card)

    return FlashcardItem(
        id=str(card.id),
        front=card.front,
        back=card.back,
        hint=card.hint,
        order_index=card.order_index,
        status=card.status,
        review_count=card.review_count,
        last_reviewed_at=card.last_reviewed_at,
    )


@router.post("/decks/{deck_id}/review", response_model=FlashcardReviewResponse, status_code=status.HTTP_201_CREATED)
async def record_deck_review(
    deck_id: str,
    req: FlashcardReviewRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Records a completed review session for a deck, batch updates card statuses,
    and updates the deck's mastered progress in PostgreSQL.
    """
    try:
        deck_uuid = uuid.UUID(deck_id)
    except (ValueError, TypeError):
        raise HTTPException(status_code=400, detail="Invalid deck ID format.")

    stmt = select(FlashcardDeck).where(
        FlashcardDeck.id == deck_uuid, FlashcardDeck.user_id == current_user.id
    )
    result = await db.execute(stmt)
    deck = result.scalar_one_or_none()

    if not deck:
        raise HTTPException(status_code=404, detail="Flashcard deck not found.")

    # Apply batch updates to cards
    now = datetime.now(timezone.utc)
    for update in req.card_updates:
        try:
            c_uuid = uuid.UUID(update.card_id)
            c_stmt = select(Flashcard).where(
                Flashcard.id == c_uuid, Flashcard.deck_id == deck.id
            )
            c_res = await db.execute(c_stmt)
            card = c_res.scalar_one_or_none()
            if card:
                card.status = update.status
                card.review_count += 1
                card.last_reviewed_at = now
        except (ValueError, TypeError):
            continue

    # Record review log
    review_record = FlashcardReview(
        id=uuid.uuid4(),
        deck_id=deck.id,
        user_id=current_user.id,
        cards_reviewed=req.cards_reviewed,
        known_count=req.known_count,
        review_again_count=req.review_again_count,
        duration_seconds=req.duration_seconds,
    )
    db.add(review_record)

    # Recalculate mastered_count for the deck
    await db.flush()
    count_stmt = (
        select(func.count(Flashcard.id))
        .where(Flashcard.deck_id == deck.id, Flashcard.status == "known")
    )
    count_res = await db.execute(count_stmt)
    deck.mastered_count = count_res.scalar() or 0

    await db.commit()
    await db.refresh(review_record)

    return FlashcardReviewResponse(
        id=str(review_record.id),
        deck_id=str(review_record.deck_id),
        user_id=str(review_record.user_id),
        cards_reviewed=review_record.cards_reviewed,
        known_count=review_record.known_count,
        review_again_count=review_record.review_again_count,
        duration_seconds=review_record.duration_seconds,
        created_at=review_record.created_at,
    )
