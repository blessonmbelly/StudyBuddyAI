from datetime import datetime, timezone
import uuid
from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import relationship

from .database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=False)
    full_name = Column(String(150), nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
        nullable=False,
    )
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    # Relationships
    refresh_tokens = relationship(
        "RefreshToken",
        back_populates="user",
        cascade="all, delete-orphan",
    )
    documents = relationship(
        "Document",
        back_populates="user",
        cascade="all, delete-orphan",
    )
    generated_notes = relationship(
        "GeneratedNote",
        back_populates="user",
        cascade="all, delete-orphan",
    )
    quizzes = relationship(
        "Quiz",
        back_populates="user",
        cascade="all, delete-orphan",
    )
    quiz_attempts = relationship(
        "QuizAttempt",
        back_populates="user",
        cascade="all, delete-orphan",
    )
    flashcard_decks = relationship(
        "FlashcardDeck",
        back_populates="user",
        cascade="all, delete-orphan",
    )
    flashcard_reviews = relationship(
        "FlashcardReview",
        back_populates="user",
        cascade="all, delete-orphan",
    )
    conversations = relationship(
        "Conversation",
        back_populates="user",
        cascade="all, delete-orphan",
    )


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    token_hash = Column(String(255), unique=True, index=True, nullable=False)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    revoked = Column(Boolean, default=False, nullable=False)
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
        nullable=False,
    )

    # Relationship
    user = relationship("User", back_populates="refresh_tokens")


class Document(Base):
    __tablename__ = "documents"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    title = Column(String(255), nullable=False)
    original_filename = Column(String(255), nullable=False)
    file_type = Column(String(20), nullable=False)  # TXT, DOCX, PDF, JPG, PNG
    subject = Column(String(100), nullable=False, default="Unknown", index=True)
    topics = Column(JSONB, nullable=False, default=list)  # list of topic string tags
    extracted_text = Column(Text, nullable=False)  # Full raw extracted text
    word_count = Column(Integer, nullable=False, default=0)
    page_count = Column(Integer, nullable=False, default=1)
    extraction_method = Column(String(50), nullable=False, default="OCR")
    processing_status = Column(String(30), nullable=False, default="completed")
    file_storage_path = Column(String(500), nullable=True)
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
        nullable=False,
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    # Relationships
    user = relationship("User", back_populates="documents")
    generated_notes = relationship(
        "GeneratedNote",
        back_populates="document",
        cascade="all, delete-orphan",
    )
    quizzes = relationship(
        "Quiz",
        back_populates="document",
        cascade="all, delete-orphan",
    )
    flashcard_decks = relationship(
        "FlashcardDeck",
        back_populates="document",
        cascade="all, delete-orphan",
    )
    conversations = relationship(
        "Conversation",
        back_populates="document",
        cascade="all, delete-orphan",
    )


class GeneratedNote(Base):
    __tablename__ = "generated_notes"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    document_id = Column(
        UUID(as_uuid=True),
        ForeignKey("documents.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    title = Column(String(255), nullable=False)
    course_name = Column(String(150), nullable=False)
    course_code = Column(String(50), nullable=False)
    summary = Column(Text, nullable=False)
    sections = Column(JSONB, nullable=False, default=list)
    key_definitions = Column(JSONB, nullable=False, default=list)
    exam_pitfalls = Column(JSONB, nullable=False, default=list)
    raw_transcript = Column(Text, nullable=False, default="")
    accuracy_percent = Column(Integer, nullable=False, default=90)
    key_terms_count = Column(Integer, nullable=False, default=5)
    read_time = Column(String(30), nullable=False, default="5 min read")
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
        nullable=False,
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    # Relationships
    user = relationship("User", back_populates="generated_notes")
    document = relationship("Document", back_populates="generated_notes")
    quizzes = relationship(
        "Quiz",
        back_populates="note",
    )
    flashcard_decks = relationship(
        "FlashcardDeck",
        back_populates="note",
    )


class Quiz(Base):
    __tablename__ = "quizzes"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    document_id = Column(
        UUID(as_uuid=True),
        ForeignKey("documents.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    note_id = Column(
        UUID(as_uuid=True),
        ForeignKey("generated_notes.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    title = Column(String(255), nullable=False)
    subject = Column(String(100), nullable=True)
    total_questions = Column(Integer, nullable=False, default=5)
    questions = Column(JSONB, nullable=False, default=list)
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
        nullable=False,
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    # Relationships
    user = relationship("User", back_populates="quizzes")
    document = relationship("Document", back_populates="quizzes")
    note = relationship("GeneratedNote", back_populates="quizzes")
    attempts = relationship(
        "QuizAttempt",
        back_populates="quiz",
        cascade="all, delete-orphan",
    )


class QuizAttempt(Base):
    __tablename__ = "quiz_attempts"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    quiz_id = Column(
        UUID(as_uuid=True),
        ForeignKey("quizzes.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    score = Column(Integer, nullable=False)  # correct answer count
    total_questions = Column(Integer, nullable=False, default=5)
    percentage = Column(Numeric(5, 2), nullable=False)
    time_spent_seconds = Column(Integer, nullable=False, default=0)
    user_answers = Column(JSONB, nullable=False, default=dict)
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
        nullable=False,
    )

    # Relationships
    quiz = relationship("Quiz", back_populates="attempts")
    user = relationship("User", back_populates="quiz_attempts")


class FlashcardDeck(Base):
    __tablename__ = "flashcard_decks"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    document_id = Column(
        UUID(as_uuid=True),
        ForeignKey("documents.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    note_id = Column(
        UUID(as_uuid=True),
        ForeignKey("generated_notes.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    title = Column(String(255), nullable=False)
    subject = Column(String(100), nullable=False, default="General", index=True)
    description = Column(Text, nullable=True)
    card_count = Column(Integer, nullable=False, default=0)
    mastered_count = Column(Integer, nullable=False, default=0)
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
        nullable=False,
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    # Relationships
    user = relationship("User", back_populates="flashcard_decks")
    document = relationship("Document", back_populates="flashcard_decks")
    note = relationship("GeneratedNote", back_populates="flashcard_decks")
    cards = relationship(
        "Flashcard",
        back_populates="deck",
        cascade="all, delete-orphan",
        order_by="Flashcard.order_index",
    )
    reviews = relationship(
        "FlashcardReview",
        back_populates="deck",
        cascade="all, delete-orphan",
    )


class Flashcard(Base):
    __tablename__ = "flashcards"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    deck_id = Column(
        UUID(as_uuid=True),
        ForeignKey("flashcard_decks.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    front = Column(Text, nullable=False)
    back = Column(Text, nullable=False)
    hint = Column(Text, nullable=True)
    order_index = Column(Integer, nullable=False, default=0)
    status = Column(String(20), nullable=False, default="unreviewed")  # unreviewed, known, learning
    review_count = Column(Integer, nullable=False, default=0)
    last_reviewed_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
        nullable=False,
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    # Relationships
    deck = relationship("FlashcardDeck", back_populates="cards")


class FlashcardReview(Base):
    __tablename__ = "flashcard_reviews"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    deck_id = Column(
        UUID(as_uuid=True),
        ForeignKey("flashcard_decks.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    cards_reviewed = Column(Integer, nullable=False, default=0)
    known_count = Column(Integer, nullable=False, default=0)
    review_again_count = Column(Integer, nullable=False, default=0)
    duration_seconds = Column(Integer, nullable=False, default=0)
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
        nullable=False,
    )

    # Relationships
    deck = relationship("FlashcardDeck", back_populates="reviews")
    user = relationship("User", back_populates="flashcard_reviews")


class Conversation(Base):
    __tablename__ = "conversations"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    document_id = Column(
        UUID(as_uuid=True),
        ForeignKey("documents.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    title = Column(String(255), nullable=False, default="General Study Chat")
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
        nullable=False,
    )
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    # Relationships
    user = relationship("User", back_populates="conversations")
    document = relationship("Document", back_populates="conversations")
    messages = relationship(
        "ChatMessage",
        back_populates="conversation",
        cascade="all, delete-orphan",
        order_by="ChatMessage.created_at",
        lazy="selectin",
    )


class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    conversation_id = Column(
        UUID(as_uuid=True),
        ForeignKey("conversations.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    sender = Column(String(20), nullable=False)  # 'user' or 'ai'
    text = Column(Text, nullable=False)
    note_reference = Column(String(255), nullable=True)
    key_takeaways = Column(JSONB, nullable=True, default=list)
    outside_context = Column(Text, nullable=True)
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
        nullable=False,
    )

    # Relationships
    conversation = relationship("Conversation", back_populates="messages")


