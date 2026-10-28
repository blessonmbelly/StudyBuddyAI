from typing import List, Optional
from pydantic import BaseModel, Field

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

class DocumentOrganizeResponse(BaseModel):
    document_id: str
    title: str
    original_filename: str
    subject: str
    topics: List[str] = []
    word_count: int
    processing_status: str = "completed"

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

class NoteGenerateResponse(BaseModel):
    id: int = 1
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

class QuizGenerateResponse(BaseModel):
    questions: List[QuizQuestion]
    total: int

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

class ChatResponse(BaseModel):
    reply: str
    note_reference: Optional[str] = None
    key_takeaways: Optional[List[str]] = None
