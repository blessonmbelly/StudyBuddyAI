from typing import List, Optional
from pydantic import BaseModel, Field

# --- Extraction Models ---
class ExtractionResponse(BaseModel):
    filename: str
    file_type: str
    extracted_text: str
    word_count: int
    extraction_method: str
    page_count: int = 1
    success: bool = True

# --- Note Generation Models ---
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
    course_code: Optional[str] = "PSYC 201"
    course_name: Optional[str] = "Cognitive Psychology"
    title: Optional[str] = None

class NoteGenerateResponse(BaseModel):
    id: int = 1
    title: str
    course_name: str
    course_code: str
    summary: str
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
    role: str  # 'user' or 'model'
    content: str

class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1)
    note_context: Optional[str] = ""
    history: Optional[List[HistoryMessage]] = []

class ChatResponse(BaseModel):
    reply: str
    note_reference: Optional[str] = None
    key_takeaways: Optional[List[str]] = None
