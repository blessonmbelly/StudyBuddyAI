from datetime import datetime
from typing import List, Optional, Union
import uuid
from pydantic import BaseModel, EmailStr, Field, field_validator

# --- Extraction Models ---
class ExtractionResponse(BaseModel):
    document_id: str = ""
    filename: str
    file_type: str
    extracted_text: str
    word_count: int
    extraction_method: str
    page_count: int = 1
    success: bool = True
    generated_title: Optional[str] = None
    detected_subject: Optional[str] = None
    topics: List[str] = []
    processing_status: str = "completed"

class DocumentOrganizeRequest(BaseModel):
    text: str = Field(..., min_length=1, description="Study material raw text")
    filename: Optional[str] = None
    page_count: Optional[int] = 1

class DocumentOrganizeResponse(BaseModel):
    document_id: str
    title: str
    original_filename: str
    subject: str
    topics: List[str] = []
    word_count: int
    processing_status: str = "completed"

class DocumentCreateRequest(BaseModel):
    title: str
    original_filename: Optional[str] = "study_document"
    file_type: Optional[str] = "TXT"
    subject: Optional[str] = "General"
    topics: Optional[List[str]] = []
    extracted_text: str
    word_count: Optional[int] = 0
    page_count: Optional[int] = 1
    extraction_method: Optional[str] = "pasted_text"
    processing_status: Optional[str] = "completed"

class DocumentUpdateRequest(BaseModel):
    title: Optional[str] = None
    subject: Optional[str] = None
    topics: Optional[List[str]] = None

class DocumentResponse(BaseModel):
    id: str
    title: str
    original_filename: str
    file_type: str
    subject: str
    topics: List[str] = []
    extracted_text: str
    word_count: int = 0
    page_count: int = 1
    extraction_method: str = "OCR"
    processing_status: str = "completed"
    created_at: Optional[datetime] = None
    generated_note: Optional[dict] = None
    generated_quiz: Optional[List[dict]] = None

    class Config:
        from_attributes = True

# --- Note Generation Models ---
class NoteBullet(BaseModel):
    term: str
    definition: str
    icon_name: str = "psychology"

class NoteSection(BaseModel):
    title: str
    description: str
    bullets: List[NoteBullet] = []

class KeyDefinition(BaseModel):
    title: str
    tag: str
    body: str

class ExamPitfall(BaseModel):
    title: str
    description: str
    concept_a: str
    concept_b: str

class NoteGenerateRequest(BaseModel):
    text: str = Field(..., min_length=1, description="Study material raw text")
    course_code: Optional[str] = None
    course_name: Optional[str] = None
    title: Optional[str] = None
    document_id: Optional[str] = None

class NoteGenerateResponse(BaseModel):
    id: Union[int, str] = 1
    title: str
    course_name: str
    course_code: str
    summary: str
    sections: List[NoteSection] = []
    key_definitions: List[KeyDefinition] = []
    exam_pitfalls: List[ExamPitfall] = []
    raw_transcript: str
    accuracy_percent: int = 85
    key_terms_count: int = 5
    read_time: str = "5 min read"
    document_id: Optional[str] = None

class NoteResponse(BaseModel):
    id: str
    title: str
    course_name: str
    course_code: str
    summary: str
    sections: List[dict] = []
    key_definitions: List[dict] = []
    exam_pitfalls: List[dict] = []
    raw_transcript: str = ""
    accuracy_percent: int = 85
    key_terms_count: int = 5
    read_time: str = "5 min read"
    document_id: Optional[str] = None
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True

# --- Quiz Generation Models ---
class QuizOption(BaseModel):
    label: str  # 'A', 'B', 'C', 'D'
    text: str
    subtitle: str = ""

class QuizQuestion(BaseModel):
    id: int
    concept: str
    question_text: str
    ai_hint: str
    options: List[QuizOption]
    correct_option_index: int
    explanation: str
    topic_badge: str
    average_time: str = "30s"

class QuizGenerateRequest(BaseModel):
    text: str = Field(..., min_length=1)
    num_questions: int = Field(default=5, ge=1, le=10)
    note_title: Optional[str] = None
    document_id: Optional[str] = None
    note_id: Optional[str] = None

class QuizGenerateResponse(BaseModel):
    questions: List[QuizQuestion]
    total: int
    quiz_id: Optional[str] = None

class QuizResponse(BaseModel):
    id: str
    title: str
    subject: Optional[str] = None
    total_questions: int
    questions: List[dict] = []
    created_at: Optional[datetime] = None
    document_id: Optional[str] = None
    note_id: Optional[str] = None

    class Config:
        from_attributes = True

class QuizAttemptCreateRequest(BaseModel):
    score: int
    total_questions: int = 5
    time_spent_seconds: int = 0
    user_answers: dict = {}

class QuizAttemptResponse(BaseModel):
    id: str
    quiz_id: str
    user_id: str
    score: int
    total_questions: int
    percentage: float
    time_spent_seconds: int
    user_answers: dict = {}
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True

# --- Flashcards Models ---
class FlashcardItem(BaseModel):
    id: Optional[str] = None
    front: str
    back: str
    hint: Optional[str] = None
    order_index: int = 0
    status: str = "unreviewed"  # unreviewed, known, learning
    review_count: int = 0
    last_reviewed_at: Optional[datetime] = None

    class Config:
        from_attributes = True

class FlashcardDeckResponse(BaseModel):
    id: str
    title: str
    subject: str = "General"
    description: Optional[str] = None
    card_count: int = 0
    mastered_count: int = 0
    cards: List[FlashcardItem] = []
    document_id: Optional[str] = None
    note_id: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True

class FlashcardGenerateRequest(BaseModel):
    text: str = Field(..., min_length=15, description="Study material raw text")
    deck_title: Optional[str] = None
    subject: Optional[str] = None
    num_cards: int = Field(default=6, ge=3, le=20)
    document_id: Optional[str] = None
    note_id: Optional[str] = None

class FlashcardCreateRequest(BaseModel):
    front: str = Field(..., min_length=1)
    back: str = Field(..., min_length=1)
    hint: Optional[str] = None

class FlashcardStatusUpdateRequest(BaseModel):
    status: str = Field(..., pattern="^(known|learning|unreviewed)$")

class CardReviewItem(BaseModel):
    card_id: str
    status: str

class FlashcardReviewRequest(BaseModel):
    cards_reviewed: int = Field(default=0, ge=0)
    known_count: int = Field(default=0, ge=0)
    review_again_count: int = Field(default=0, ge=0)
    duration_seconds: int = Field(default=0, ge=0)
    card_updates: List[CardReviewItem] = []

class FlashcardReviewResponse(BaseModel):
    id: str
    deck_id: str
    user_id: str
    cards_reviewed: int
    known_count: int
    review_again_count: int
    duration_seconds: int
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True

# --- Chat Models ---
class HistoryMessage(BaseModel):
    role: str = "user"  # 'user' or 'model'
    content: Optional[str] = None
    text: Optional[str] = None

    @property
    def message_text(self) -> str:
        return self.content or self.text or ""

class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1)
    note_context: Optional[str] = ""
    history: Optional[List[HistoryMessage]] = []
    conversation_id: Optional[str] = None
    document_id: Optional[str] = None

class ChatResponse(BaseModel):
    reply: str
    note_reference: Optional[str] = None
    key_takeaways: Optional[List[str]] = None
    outside_knowledge_used: bool = False
    conversation_id: Optional[str] = None
    message_id: Optional[str] = None

class ChatMessageItem(BaseModel):
    id: str
    conversation_id: str
    sender: str  # 'user' or 'ai'
    text: str
    note_reference: Optional[str] = None
    key_takeaways: Optional[List[str]] = None
    outside_context: Optional[str] = None
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True

class ConversationResponse(BaseModel):
    id: str
    user_id: str
    document_id: Optional[str] = None
    title: str
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    messages: List[ChatMessageItem] = []

    class Config:
        from_attributes = True

class ConversationSummaryResponse(BaseModel):
    id: str
    document_id: Optional[str] = None
    title: str
    message_count: int = 0
    last_message: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True

class ConversationCreateRequest(BaseModel):
    document_id: Optional[str] = None
    title: Optional[str] = None

class ChatMessageSendRequest(BaseModel):
    message: str = Field(..., min_length=1)
    conversation_id: Optional[str] = None
    document_id: Optional[str] = None


# --- Authentication Models ---
class UserRegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=8, max_length=72, description="Password must be between 8 and 72 characters")
    full_name: Optional[str] = Field(None, max_length=150)

    @field_validator("email", mode="before")
    @classmethod
    def normalize_email(cls, v: str) -> str:
        if isinstance(v, str):
            return v.strip().lower()
        return v


class UserLoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=1, max_length=72)

    @field_validator("email", mode="before")
    @classmethod
    def normalize_email(cls, v: str) -> str:
        if isinstance(v, str):
            return v.strip().lower()
        return v


class UserResponse(BaseModel):
    id: uuid.UUID
    email: str
    full_name: Optional[str] = None
    is_active: bool
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    user: UserResponse


class RefreshTokenRequest(BaseModel):
    refresh_token: str = Field(..., min_length=1, description="Raw refresh token string")


class LogoutRequest(BaseModel):
    refresh_token: Optional[str] = None


class MessageResponse(BaseModel):
    message: str

