import json
import logging
import re
import time
from typing import List, Optional
from fastapi import HTTPException
from google import genai
from google.genai import types

from .config import settings
from .models import (
    NoteBullet,
    NoteSection,
    KeyDefinition,
    ExamPitfall,
    NoteGenerateResponse,
    QuizOption,
    QuizQuestion,
    QuizGenerateResponse,
    ChatResponse,
    HistoryMessage,
)

logger = logging.getLogger(__name__)


def get_gemini_client() -> Optional[genai.Client]:
    """Returns a configured Gemini Client or None if unconfigured."""
    if not settings.is_gemini_configured:
        return None
    try:
        return genai.Client(
            api_key=settings.GEMINI_API_KEY,
            http_options=types.HttpOptions(timeout=45000),
        )
    except Exception as e:
        logger.error(f"Failed to initialize Gemini client: {e}")
        return None


def handle_gemini_exception(e: Exception) -> HTTPException:
    """Categorizes Gemini SDK exceptions into descriptive HTTPExceptions."""
    if isinstance(e, HTTPException):
        return e

    err_str = str(e).lower()
    logger.error(f"Gemini API Exception: {e}", exc_info=True)

    # High demand / transient service unavailable
    if "503" in err_str or "unavailable" in err_str or "high demand" in err_str:
        return HTTPException(
            status_code=503,
            detail="Gemini AI is temporarily experiencing high demand. Please retry in a few moments.",
        )

    # Quota exhaustion / rate limit
    if "429" in err_str or "resource_exhausted" in err_str or "quota" in err_str:
        return HTTPException(
            status_code=429,
            detail=f"Gemini API quota exceeded: {str(e)}. Please check your Google AI Studio quota limits.",
        )

    # Timeouts / deadline exceeded
    if "timeout" in err_str or "timed out" in err_str or "deadline_exceeded" in err_str:
        return HTTPException(
            status_code=504,
            detail="Gemini AI request timed out. Please retry with a shorter document or try again shortly.",
        )

    # Bad response / server error
    return HTTPException(
        status_code=502,
        detail=f"Gemini AI service error: {str(e)}",
    )


def generate_content_with_retry(
    client: genai.Client,
    model: str,
    contents,
    config=None,
    max_retries: int = 3,
):
    """Executes generate_content with backoff for transient 503 / high-demand spikes."""
    last_err = None
    for attempt in range(max_retries + 1):
        try:
            return client.models.generate_content(
                model=model,
                contents=contents,
                config=config,
            )
        except Exception as e:
            last_err = e
            err_str = str(e).lower()
            if ("503" in err_str or "unavailable" in err_str or "high demand" in err_str) and attempt < max_retries:
                wait_time = 2.0 * (attempt + 1)
                logger.warning(
                    f"Gemini transient 503 spike encountered. Retrying in {wait_time}s (attempt {attempt + 1}/{max_retries})..."
                )
                time.sleep(wait_time)
                continue
            raise e
    raise last_err


def clean_and_parse_json(raw_text: str) -> dict:
    """Safely extracts and parses JSON from Gemini output, handling markdown fences."""
    if not raw_text or not raw_text.strip():
        raise HTTPException(
            status_code=502,
            detail="Gemini AI returned an empty response.",
        )

    cleaned = raw_text.strip()
    # Remove markdown code block wrappers if present
    if cleaned.startswith("```"):
        cleaned = re.sub(r"^```(?:json)?\s*", "", cleaned)
        cleaned = re.sub(r"\s*```$", "", cleaned)

    try:
        return json.loads(cleaned)
    except json.JSONDecodeError:
        # Attempt to isolate outermost JSON object { ... }
        match = re.search(r"\{.*\}", cleaned, re.DOTALL)
        if match:
            try:
                return json.loads(match.group(0))
            except json.JSONDecodeError:
                pass
        logger.error(f"Failed to parse JSON from AI response: {raw_text[:300]}")
        raise HTTPException(
            status_code=502,
            detail="Failed to parse structured JSON response from Gemini AI. Model response was malformed.",
        )


# --- OCR with Gemini Multimodal (Images and Scanned PDFs) ---
def perform_gemini_ocr(content: bytes, mime_type: str = "image/jpeg") -> str:
    """Uses Gemini multimodal model to perform high-accuracy OCR on images and PDFs."""
    client = get_gemini_client()
    if not client:
        raise HTTPException(
            status_code=503,
            detail="Gemini AI is not configured. Please add a valid GEMINI_API_KEY to backend/.env for OCR extraction.",
        )

    try:
        part = types.Part.from_bytes(data=content, mime_type=mime_type)
        prompt = (
            "You are an expert OCR engine for student notes, textbooks, and lecture slides. "
            "Extract all readable text with high precision across all pages. Preserve headings, numbered lists, bullet points, "
            "and definitions. Output ONLY the extracted text with no conversational preamble or markdown code blocks."
        )
        response = generate_content_with_retry(
            client=client,
            model=settings.GEMINI_MODEL,
            contents=[part, prompt],
        )
        text = response.text or ""
        return text.strip()
    except Exception as e:
        logger.error(f"Gemini OCR error: {e}")
        raise handle_gemini_exception(e)


# --- Note Generation ---
def generate_study_notes(
    text: str,
    course_code: Optional[str] = None,
    course_name: Optional[str] = None,
    title: Optional[str] = None,
) -> NoteGenerateResponse:
    """Generates a structured short note deck from raw extracted text."""
    client = get_gemini_client()
    if not client:
        raise HTTPException(
            status_code=503,
            detail="Gemini AI is not configured. Please set GEMINI_API_KEY in backend/.env to generate study notes.",
        )

    try:
        # Large context window support (up to 60,000 chars safely)
        truncated_text = text[:60000]
        course_hint = (
            f"Target Course: {course_name} ({course_code})"
            if course_name and course_code
            else "Infer the most accurate academic course name and a standard 3-digit course code (e.g. BIO 201, CS 310, CHEM 102, HIST 101, ECON 202) directly from the content."
        )
        title_hint = (
            f"Specified Title: {title}"
            if title
            else "Extract a clear, concise academic topic title reflecting the core subject."
        )

        prompt = f"""You are an elite academic AI tutor. Analyze this study material and create a comprehensive, structured short-note study deck.
{course_hint}
{title_hint}

Study Material:
\"\"\"
{truncated_text}
\"\"\"

Return a valid JSON object matching this schema:
{{
  "title": "Clear concise topic title based on the material",
  "course_name": "Inferred or specified subject name",
  "course_code": "Inferred or specified course code (e.g. BIO 201, CS 310)",
  "summary": "2-3 sentence high-yield summary of key principles in the material",
  "sections": [
    {{
      "title": "Descriptive Section Heading (e.g. Core Mechanisms, Structural Framework, Primary Rules)",
      "description": "1 sentence introducing this concept group",
      "bullets": [
        {{
          "term": "Key Concept or Mechanism",
          "definition": "Clear, precise explanation based strictly on the material",
          "icon_name": "school"
        }}
      ]
    }}
  ],
  "key_definitions": [
    {{
      "title": "Term name",
      "tag": "Category, law, model, or citation",
      "body": "Precise academic definition"
    }}
  ],
  "exam_pitfalls": [
    {{
      "title": "Common exam pitfall or confusion point",
      "description": "Why students lose points and how to distinguish correctly",
      "concept_a": "First easily confused concept",
      "concept_b": "Second easily confused concept"
    }}
  ],
  "accuracy_percent": 94,
  "key_terms_count": 6,
  "read_time": "5 min read"
}}
"""
        response = generate_content_with_retry(
            client=client,
            model=settings.GEMINI_MODEL,
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                temperature=0.2,
            ),
        )
        data = clean_and_parse_json(response.text)

        # Parse sections
        raw_sections = data.get("sections", [])
        sections = []
        if isinstance(raw_sections, list):
            for s in raw_sections:
                if isinstance(s, dict):
                    bullets = []
                    for b in s.get("bullets", []):
                        if isinstance(b, dict):
                            bullets.append(
                                NoteBullet(
                                    term=str(b.get("term", "Key Concept")),
                                    definition=str(b.get("definition", "")),
                                    icon_name=str(b.get("icon_name", "psychology")),
                                )
                            )
                    sections.append(
                        NoteSection(
                            title=str(s.get("title", "Key Principles")),
                            description=str(s.get("description", "")),
                            bullets=bullets,
                        )
                    )

        # Fallback section if model returned none
        raw_defs = data.get("key_definitions", [])
        if not sections and isinstance(raw_defs, list) and raw_defs:
            fallback_bullets = [
                NoteBullet(
                    term=str(kd.get("title", "Core Concept")),
                    definition=str(kd.get("body", "")),
                    icon_name="psychology",
                )
                for kd in raw_defs
                if isinstance(kd, dict)
            ]
            sections.append(
                NoteSection(
                    title="Core Principles & Terminology",
                    description="Key mechanisms extracted directly from the study material.",
                    bullets=fallback_bullets,
                )
            )

        key_definitions = [
            KeyDefinition(**kd)
            for kd in raw_defs
            if isinstance(kd, dict) and "title" in kd and "body" in kd
        ]

        raw_pitfalls = data.get("exam_pitfalls", [])
        exam_pitfalls = [
            ExamPitfall(**ep)
            for ep in raw_pitfalls
            if isinstance(ep, dict) and "title" in ep and "description" in ep
        ]

        return NoteGenerateResponse(
            id=1,
            title=title or data.get("title", "Synthesized Study Notes"),
            course_name=course_name or data.get("course_name", "General Academic Study"),
            course_code=course_code or data.get("course_code", "STUDY 101"),
            summary=data.get("summary", "Summary of extracted concepts."),
            sections=sections,
            key_definitions=key_definitions,
            exam_pitfalls=exam_pitfalls,
            raw_transcript=text,
            accuracy_percent=data.get("accuracy_percent", 92),
            key_terms_count=data.get("key_terms_count", max(len(key_definitions), 3)),
            read_time=data.get("read_time", "5 min read"),
        )
    except Exception as e:
        logger.error(f"Gemini note generation error: {e}")
        raise handle_gemini_exception(e)


# --- Quiz Generation ---
def generate_quiz_questions(
    text: str,
    num_questions: int = 5,
    note_title: Optional[str] = None,
) -> QuizGenerateResponse:
    """Generates MCQs with exactly 4 options and 1 validated correct answer grounded in the material."""
    client = get_gemini_client()
    if not client:
        raise HTTPException(
            status_code=503,
            detail="Gemini AI is not configured. Please set GEMINI_API_KEY in backend/.env to generate quiz questions.",
        )

    try:
        truncated_text = text[:60000]
        prompt = f"""You are a master academic examiner. Based strictly on the study text below, create {num_questions} high-quality multiple-choice questions (MCQs).

Study Text:
\"\"\"
{truncated_text}
\"\"\"

Requirements:
- Exactly {num_questions} questions.
- Each question must have EXACTLY 4 options (with labels "A", "B", "C", "D").
- Each option must have a "text" (concise, clear answer choice) and a helpful "subtitle" (short contextual rationale or concept).
- Exactly ONE option is correct. "correct_option_index" must be an integer from 0 to 3 pointing to the single correct option in the options array.
- The "explanation" must thoroughly explain why the correct option (at correct_option_index) is factually accurate based on the study text, and why the other options are distractors.
- Include a 1-sentence "ai_hint" and a concise "topic_badge" (e.g. "Core Theory", "Neuroanatomy").
- Include a specific "concept" name.

Return a valid JSON object matching this schema:
{{
  "questions": [
    {{
      "id": 1,
      "concept": "Specific concept name",
      "question_text": "Clear academic question?",
      "ai_hint": "Cognitive clue to guide retrieval without giving away the answer",
      "options": [
        {{"label": "A", "text": "Option text", "subtitle": "Option rationale or detail"}},
        {{"label": "B", "text": "Option text", "subtitle": "Option rationale or detail"}},
        {{"label": "C", "text": "Option text", "subtitle": "Option rationale or detail"}},
        {{"label": "D", "text": "Option text", "subtitle": "Option rationale or detail"}}
      ],
      "correct_option_index": 0,
      "explanation": "Detailed explanation validating why option A is correct based on the text.",
      "topic_badge": "Concept Recall",
      "average_time": "30s"
    }}
  ]
}}
"""
        response = generate_content_with_retry(
            client=client,
            model=settings.GEMINI_MODEL,
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                temperature=0.2,
            ),
        )
        data = clean_and_parse_json(response.text)
        raw_qs = data.get("questions", [])
        if not raw_qs:
            raise HTTPException(status_code=502, detail="Gemini returned an empty question list.")

        questions = []
        labels = ["A", "B", "C", "D"]
        for i, q in enumerate(raw_qs):
            raw_opts = q.get("options", [])
            opts = []
            for j, opt in enumerate(raw_opts[:4]):
                opts.append(
                    QuizOption(
                        label=labels[j] if j < len(labels) else "A",
                        text=opt.get("text", f"Option {labels[j]}"),
                        subtitle=opt.get("subtitle", ""),
                    )
                )
            while len(opts) < 4:
                j = len(opts)
                opts.append(
                    QuizOption(
                        label=labels[j],
                        text=f"Distractor Choice {labels[j]}",
                        subtitle="Incorrect alternative",
                    )
                )

            correct_idx = q.get("correct_option_index", 0)
            if not isinstance(correct_idx, int) or not (0 <= correct_idx <= 3):
                correct_idx = 0

            questions.append(
                QuizQuestion(
                    id=i + 1,
                    concept=q.get("concept", f"Concept {i + 1}"),
                    question_text=q.get("question_text", "What is the primary concept described in the text?"),
                    ai_hint=q.get("ai_hint", "Recall the core principles mentioned in the study material."),
                    options=opts,
                    correct_option_index=correct_idx,
                    explanation=q.get("explanation", f"Option {labels[correct_idx]} directly reflects the study material."),
                    topic_badge=q.get("topic_badge", "Concept Recall"),
                    average_time=q.get("average_time", "30s"),
                )
            )

        return QuizGenerateResponse(questions=questions, total=len(questions))
    except Exception as e:
        logger.error(f"Gemini quiz generation error: {e}")
        raise handle_gemini_exception(e)


# --- Flashcards Generation ---
def generate_flashcards(
    text: str,
    num_cards: int = 6,
    deck_title: Optional[str] = None,
    subject: Optional[str] = None,
) -> dict:
    """
    Generates Q&A flashcards grounded strictly in the provided study material.
    Returns a dict with 'title', 'subject', 'description', and 'cards' (list of dicts with front, back, hint).
    """
    client = get_gemini_client()
    if not client:
        raise HTTPException(
            status_code=503,
            detail="Gemini AI is not configured. Please set GEMINI_API_KEY in backend/.env to generate flashcards.",
        )

    try:
        truncated_text = text[:60000]
        title_hint = f'"{deck_title}"' if deck_title else "a descriptive academic deck title"
        subj_hint = f'"{subject}"' if subject else "the primary academic discipline"

        prompt = f"""You are an elite academic study coach specializing in active recall and spaced repetition flashcards.
Based strictly on the source study material below, extract the most important core concepts, key mechanisms, definitions, formulas, and critical distinctions to create exactly {num_cards} flashcards.

Study Material:
\"\"\"
{truncated_text}
\"\"\"

Requirements:
- Create exactly {num_cards} cards.
- "front": A clear, thought-provoking question, key term, or conceptual challenge for active recall (e.g. "What is the primary role of the hippocampus in memory consolidation?", "Define Long-Term Potentiation (LTP)").
- "back": A clear, accurate, and concise answer explaining the concept factually based on the text (1-3 sentences).
- "hint": A brief, helpful cognitive clue that prompts recall without giving the answer away directly.
- Identify a suitable "title" (e.g. {title_hint}) and "subject" (e.g. {subj_hint}).
- Provide a 1-sentence "description" summarizing what this deck covers.

Return a valid JSON object matching this schema:
{{
  "title": "Title of the Deck",
  "subject": "Academic Subject / Field",
  "description": "Short overview of cards included.",
  "cards": [
    {{
      "front": "Question or active recall prompt",
      "back": "Accurate, concise answer or definition",
      "hint": "Brief memory clue"
    }}
  ]
}}
"""
        response = generate_content_with_retry(
            client=client,
            model=settings.GEMINI_MODEL,
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                temperature=0.2,
            ),
        )
        data = clean_and_parse_json(response.text)
        raw_cards = data.get("cards", [])
        if not raw_cards:
            raise HTTPException(status_code=502, detail="Gemini returned an empty flashcard list.")

        cards = []
        for i, c in enumerate(raw_cards[:num_cards]):
            if isinstance(c, dict):
                front = str(c.get("front", f"Core Concept {i + 1}")).strip()
                back = str(c.get("back", "Key principle described in study notes.")).strip()
                hint = c.get("hint")
                if hint:
                    hint = str(hint).strip()
                cards.append({
                    "front": front,
                    "back": back,
                    "hint": hint,
                    "order_index": i,
                })

        return {
            "title": deck_title or data.get("title", "Study Flashcards"),
            "subject": subject or data.get("subject", "General"),
            "description": data.get("description", f"Active recall deck containing {len(cards)} key cards."),
            "cards": cards,
        }
    except Exception as e:
        logger.error(f"Gemini flashcard generation error: {e}")
        raise handle_gemini_exception(e)


# --- Chat with Notes ---
def answer_student_chat(
    message: str,
    note_context: str = "",
    history: Optional[List[HistoryMessage]] = None,
) -> ChatResponse:
    """Answers a student question grounded strictly on the study note."""
    client = get_gemini_client()
    if not client:
        raise HTTPException(
            status_code=503,
            detail="Gemini AI is not configured. Please set GEMINI_API_KEY in backend/.env to use AI chat.",
        )

    try:
        conversation_history = []
        if history:
            for h in history[-8:]:
                h_text = h.content or h.text or ""
                conversation_history.append(f"{h.role.capitalize()}: {h_text}")

        history_str = "\n".join(conversation_history)
        prompt = f"""You are StudyBuddy AI, an encouraging and academically rigorous study partner.
Answer the student's question grounded strictly on the provided study notes.

Study Note Context:
\"\"\"
{note_context[:40000] if note_context else "General Academic Principles"}
\"\"\"

Recent Conversation:
{history_str}

Student Question:
\"{message}\"

Instructions:
- Give a clear, academically accurate answer grounded in the study note context (2-4 sentences).
- If the question cannot be answered from the study context, acknowledge this gently and answer based on general principles while advising the student to check their notes.
- Include 2-3 bullet point key takeaways.
- Provide a relevant note_reference title or concept.

Format your response as a JSON object matching this schema:
{{
  "reply": "Clear, grounded answer to the student question.",
  "note_reference": "Relevant concept or section name from notes",
  "key_takeaways": [
    "Key takeaway 1",
    "Key takeaway 2"
  ]
}}
"""
        response = generate_content_with_retry(
            client=client,
            model=settings.GEMINI_MODEL,
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                temperature=0.3,
            ),
        )
        data = clean_and_parse_json(response.text)
        return ChatResponse(
            reply=data.get("reply", "Here is the key insight from your notes."),
            note_reference=data.get("note_reference", "Verified Study Note"),
            key_takeaways=data.get("key_takeaways", []),
        )
    except Exception as e:
        logger.error(f"Gemini chat error: {e}")
        raise handle_gemini_exception(e)


# --- Smart Document Organization ---
def organize_study_document(text: str, filename: str = "document") -> dict:
    """
    Analyzes study material content to generate:
    - title: Meaningful, concise academic topic title (3-7 words)
    - subject: Academic discipline / subject (e.g. Biology, Economics, CS)
    - topics: 2-5 relevant core topic keywords/tags
    Falls back gracefully to cleaned filename and 'Unknown' subject if identification fails.
    """
    clean_fallback_title = (
        filename.rsplit(".", 1)[0].replace("-", " ").replace("_", " ").strip()
        if filename
        else "Study Document"
    )
    if not clean_fallback_title:
        clean_fallback_title = "Study Document"

    # Minimal or empty text fallback
    if not text or len(text.strip()) < 10:
        return {
            "title": clean_fallback_title,
            "subject": "Unknown",
            "topics": [],
            "processing_status": "fallback",
        }

    client = get_gemini_client()
    if not client:
        logger.warning("Gemini AI client not configured. Falling back to default title and Unknown subject.")
        return {
            "title": clean_fallback_title,
            "subject": "Unknown",
            "topics": [],
            "processing_status": "fallback",
        }

    try:
        sample_text = text[:4000].strip()
        prompt = f"""You are an expert academic curriculum librarian. Analyze the following study text and generate:
1. "title": A clear, specific, concise title (3 to 7 words) that accurately captures the central concept or lecture topic. Do NOT use generic names like "Lecture Notes" or "Untitled".
2. "subject": The primary academic field/discipline (e.g., Biology, Computer Science, Economics, Psychology, Chemistry, History, Mathematics, Physics, Medicine, Law, Philosophy, Engineering, Literature). If you cannot determine the subject with confidence, return "Unknown".
3. "topics": A list of 2 to 5 specific conceptual keywords or subtopics discussed in the text (e.g., ["Calvin Cycle", "Light Reactions", "ATP Synthesis"]).

Document Content:
\"\"\"
{sample_text}
\"\"\"

Output strictly a JSON object matching this schema:
{{
  "title": "Specific Topic Title",
  "subject": "Academic Subject Name",
  "topics": ["Topic 1", "Topic 2", "Topic 3"]
}}
"""
        response = generate_content_with_retry(
            client=client,
            model=settings.GEMINI_MODEL,
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                temperature=0.2,
            ),
        )
        data = clean_and_parse_json(response.text)
        title = str(data.get("title", "")).strip() or clean_fallback_title
        subject = str(data.get("subject", "")).strip() or "Unknown"
        raw_topics = data.get("topics", [])
        topics = [str(t).strip() for t in raw_topics if str(t).strip()] if isinstance(raw_topics, list) else []

        return {
            "title": title,
            "subject": subject,
            "topics": topics,
            "processing_status": "completed",
        }
    except Exception as e:
        logger.warning(f"Smart document organization fallback triggered: {e}")
        return {
            "title": clean_fallback_title,
            "subject": "Unknown",
            "topics": [],
            "processing_status": "fallback",
        }

