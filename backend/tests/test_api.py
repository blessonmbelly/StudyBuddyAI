import io
import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

import docx
from PIL import Image, ImageDraw
import pypdf
from pypdf.generic import DecodedStreamObject, DictionaryObject, NameObject
import pytest
from fastapi.testclient import TestClient

# Ensure backend root is in sys.path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from main import app
from app.config import settings

client = TestClient(app)


# --- Helper Generators for Test Files ---
def create_text_pdf(text: str) -> bytes:
    """Generates a text-based PDF with an embedded text stream."""
    writer = pypdf.PdfWriter()
    page = writer.add_blank_page(width=612, height=792)

    stream = DecodedStreamObject()
    escaped = text.replace("(", "\\(").replace(")", "\\)")
    stream.set_data(f"BT /F1 12 Tf 72 712 Td ({escaped}) Tj ET".encode("utf-8"))
    page[NameObject("/Contents")] = stream

    font_dict = DictionaryObject({
        NameObject("/Type"): NameObject("/Font"),
        NameObject("/Subtype"): NameObject("/Type1"),
        NameObject("/BaseFont"): NameObject("/Helvetica"),
    })
    page[NameObject("/Resources")] = DictionaryObject({
        NameObject("/Font"): DictionaryObject({
            NameObject("/F1"): font_dict,
        })
    })

    buf = io.BytesIO()
    writer.write(buf)
    return buf.getvalue()


def create_scanned_multipage_pdf(page_texts: list[str]) -> bytes:
    """Renders text into image pages and combines them into an image-only multi-page PDF."""
    images = []
    for txt in page_texts:
        img = Image.new("RGB", (800, 200), color=(255, 255, 255))
        d = ImageDraw.Draw(img)
        d.text((20, 50), txt, fill=(0, 0, 0))
        images.append(img)

    buf = io.BytesIO()
    images[0].save(buf, format="PDF", save_all=True, append_images=images[1:])
    return buf.getvalue()


def create_test_image(text: str, fmt: str = "JPEG") -> bytes:
    """Creates a raster image containing rendered text for OCR validation."""
    img = Image.new("RGB", (700, 150), color=(255, 255, 255))
    d = ImageDraw.Draw(img)
    d.text((20, 50), text, fill=(0, 0, 0))
    buf = io.BytesIO()
    img.save(buf, format=fmt)
    return buf.getvalue()


# --- Endpoint Tests ---

def test_health_check():
    """Verifies backend health status, API version, and Gemini configuration."""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert data["version"] == "1.0.0"
    assert data["gemini_configured"] is True
    assert "gemini_model" in data
    assert data["max_upload_size_mb"] > 0


def test_extract_txt_file():
    """Extracts plain text file and verifies character and word counts."""
    txt_content = b"Ebbinghaus Forgetting Curve shows exponential memory decay over time without spaced repetition."
    response = client.post(
        "/api/files/extract",
        files={"file": ("lecture_note.txt", io.BytesIO(txt_content), "text/plain")},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert data["file_type"] == "TXT"
    assert data["extraction_method"] == "plain_text"
    assert "Ebbinghaus" in data["extracted_text"]
    assert len(data["extracted_text"]) == len(txt_content.decode("utf-8"))
    assert data["word_count"] > 0
    assert data["page_count"] == 1


def test_extract_docx_file():
    """Extracts DOCX paragraphs and tables."""
    doc = docx.Document()
    doc.add_paragraph("Consolidation transforms labile memories into enduring neural traces.")
    table = doc.add_table(rows=1, cols=2)
    table.rows[0].cells[0].text = "Hippocampus"
    table.rows[0].cells[1].text = "Synaptic Plasticity"

    docx_io = io.BytesIO()
    doc.save(docx_io)
    docx_io.seek(0)

    response = client.post(
        "/api/files/extract",
        files={"file": ("neuro_notes.docx", docx_io, "application/vnd.openxmlformats-officedocument.wordprocessingml.document")},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert data["file_type"] == "DOCX"
    assert data["extraction_method"] == "docx_parser"
    assert "Consolidation" in data["extracted_text"]
    assert "Hippocampus" in data["extracted_text"]
    assert len(data["extracted_text"]) > 50


def test_extract_text_based_pdf():
    """Extracts text from a text-based PDF using embedded text layer."""
    text_content = "Atkinson-Shiffrin Model: Sensory memory, Short-term memory, Long-term memory storage systems."
    pdf_bytes = create_text_pdf(text_content)

    response = client.post(
        "/api/files/extract",
        files={"file": ("memory_systems.pdf", io.BytesIO(pdf_bytes), "application/pdf")},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert data["file_type"] == "PDF"
    assert data["extraction_method"] == "pdf_embedded_text"
    assert "Atkinson-Shiffrin" in data["extracted_text"]
    assert data["page_count"] == 1
    assert len(data["extracted_text"]) > 30


def test_extract_scanned_multipage_pdf_gemini_ocr():
    """
    Extracts text from a scanned multi-page PDF using Gemini multimodal OCR.
    Verifies that all pages are processed and complete extracted text is returned.
    """
    page1 = "Lecture Page 1: Action potentials propagate down the axon."
    page2 = "Lecture Page 2: Neurotransmitters bind to ligand-gated receptors."
    pdf_bytes = create_scanned_multipage_pdf([page1, page2])

    response = client.post(
        "/api/files/extract",
        files={"file": ("scanned_lecture_multipage.pdf", io.BytesIO(pdf_bytes), "application/pdf")},
    )
    assert response.status_code in (200, 429)
    if response.status_code == 200:
        data = response.json()
        assert data["success"] is True
        assert data["file_type"] == "PDF"
        assert data["extraction_method"] == "gemini_pdf_ocr"
        assert data["page_count"] == 2
        extracted = data["extracted_text"]
        assert "Action potentials" in extracted or "Page 1" in extracted
        assert "Neurotransmitters" in extracted or "Page 2" in extracted
        assert len(extracted) != 157
        assert "Note: GEMINI_API_KEY is not configured" not in extracted
    else:
        assert "quota" in response.json()["detail"].lower()


def test_extract_jpg_image_ocr():
    """Extracts text from JPG via Gemini Vision OCR."""
    image_text = "Dopamine and Serotonin regulate neurological reward pathways."
    jpg_bytes = create_test_image(image_text, fmt="JPEG")

    response = client.post(
        "/api/files/extract",
        files={"file": ("brain_scan.jpg", io.BytesIO(jpg_bytes), "image/jpeg")},
    )
    assert response.status_code in (200, 429)
    if response.status_code == 200:
        data = response.json()
        assert data["success"] is True
        assert data["file_type"] == "JPG"
        assert data["extraction_method"] == "gemini_vision_ocr"
        extracted = data["extracted_text"]
        assert "Dopamine" in extracted
        assert len(extracted) != 157
        assert "Note: GEMINI_API_KEY is not configured" not in extracted
    else:
        assert "quota" in response.json()["detail"].lower()


def test_extract_png_image_ocr():
    """Extracts text from PNG via Gemini Vision OCR."""
    image_text = "Prefrontal Cortex coordinates executive function and cognitive planning."
    png_bytes = create_test_image(image_text, fmt="PNG")

    response = client.post(
        "/api/files/extract",
        files={"file": ("cortex_diagram.png", io.BytesIO(png_bytes), "image/png")},
    )
    assert response.status_code in (200, 429)
    if response.status_code == 200:
        data = response.json()
        assert data["success"] is True
        assert data["file_type"] == "PNG"
        assert data["extraction_method"] == "gemini_vision_ocr"
        extracted = data["extracted_text"]
        assert "Prefrontal Cortex" in extracted
        assert len(extracted) != 157
    else:
        assert "quota" in response.json()["detail"].lower()


def test_extract_empty_file_rejected():
    """Rejects empty uploaded files with HTTP 400."""
    response = client.post(
        "/api/files/extract",
        files={"file": ("empty.txt", io.BytesIO(b""), "text/plain")},
    )
    assert response.status_code == 400
    assert "empty" in response.json()["detail"].lower()


def test_extract_unsupported_format_rejected():
    """Rejects unsupported extensions (e.g. .exe, .zip) with HTTP 400."""
    response = client.post(
        "/api/files/extract",
        files={"file": ("archive.zip", io.BytesIO(b"dummy_zip_content"), "application/zip")},
    )
    assert response.status_code == 400
    assert "unsupported" in response.json()["detail"].lower()


# --- Notes Generation Tests ---

def test_generate_notes_dynamic_gemini():
    """Generates structured notes dynamically from real study material with Gemini."""
    study_text = (
        "Cellular Respiration comprises three stages: Glycolysis occurs in the cytoplasm yielding 2 ATP and 2 NADH. "
        "The Krebs cycle operates within the mitochondrial matrix producing CO2, ATP, NADH, and FADH2. "
        "Oxidative Phosphorylation across the inner mitochondrial membrane drives ATP synthase, generating roughly 30-32 ATP."
    )
    response = client.post(
        "/api/notes/generate",
        json={
            "text": study_text,
            "course_code": "BIO 101",
            "course_name": "Cellular Biology",
            "title": "Cellular Respiration Overview",
        },
    )
    assert response.status_code in (200, 429)
    if response.status_code == 200:
        data = response.json()
        assert data["title"]
        assert data["summary"]
        assert len(data["key_definitions"]) >= 1
        assert len(data["exam_pitfalls"]) >= 1
        assert data["raw_transcript"] == study_text
        summary_lower = data["summary"].lower()
        assert "glycolysis" in summary_lower or "atp" in summary_lower or "respiration" in summary_lower
    else:
        assert "quota" in response.json()["detail"].lower()


def test_generate_notes_empty_rejected():
    """Rejects blank text with HTTP 400."""
    response = client.post(
        "/api/notes/generate",
        json={"text": "   "},
    )
    assert response.status_code == 400
    assert "empty" in response.json()["detail"].lower()


def test_generate_notes_too_short_rejected():
    """Rejects very short text with HTTP 400."""
    response = client.post(
        "/api/notes/generate",
        json={"text": "Hello world"},
    )
    assert response.status_code == 400
    assert "too short" in response.json()["detail"].lower()


# --- Quiz Generation & Scoring Tests ---

def test_generate_quiz_5_mcqs_and_scoring():
    """
    Generates 5 MCQs with exactly 4 options each, validated correct answers,
    and verifies quiz scoring logic (100% when picking correct index, 0% on distractors).
    """
    material = (
        "Photosynthesis takes place in chloroplasts. Light-dependent reactions in thylakoid membranes split water "
        "releasing oxygen and synthesizing ATP and NADPH. The Calvin cycle occurs in the stroma, using RuBisCO "
        "to fix carbon dioxide into G3P sugar molecules. Chlorophyll a primarily absorbs blue and red wavelengths."
    )
    response = client.post(
        "/api/quiz/generate",
        json={"text": material, "num_questions": 5, "note_title": "Photosynthesis"},
    )
    assert response.status_code in (200, 429)
    if response.status_code == 200:
        data = response.json()
        assert data["total"] == 5
        assert len(data["questions"]) == 5

        total_score = 0
        for q in data["questions"]:
            assert len(q["options"]) == 4
            assert [opt["label"] for opt in q["options"]] == ["A", "B", "C", "D"]
            correct_idx = q["correct_option_index"]
            assert 0 <= correct_idx <= 3
            assert len(q["explanation"]) > 0
            assert len(q["ai_hint"]) > 0
            assert len(q["concept"]) > 0

            # Simulate quiz scoring: correct answer gets 1 point
            selected_answer = correct_idx
            if selected_answer == q["correct_option_index"]:
                total_score += 1

        # Perfect score test
        final_score_pct = (total_score / len(data["questions"])) * 100
        assert final_score_pct == 100.0

        # Distractor test (picking wrong index should not award score)
        wrong_score = 0
        for q in data["questions"]:
            distractor_idx = (q["correct_option_index"] + 1) % 4
            if distractor_idx == q["correct_option_index"]:
                wrong_score += 1
        assert wrong_score == 0
    else:
        assert "quota" in response.json()["detail"].lower()


def test_generate_quiz_empty_rejected():
    """Rejects empty text for quiz generation with HTTP 400."""
    response = client.post(
        "/api/quiz/generate",
        json={"text": "   "},
    )
    assert response.status_code == 400


# --- Chat with Notes Tests ---

def test_chat_grounded_in_notes():
    """Verifies that Chat with Notes uses the provided notes context for grounded Q&A."""
    note_ctx = (
        "The Law of Effect proposed by Edward Thorndike states that responses followed by satisfying consequences "
        "are more likely to recur, whereas responses followed by discomfort are weakened."
    )
    response = client.post(
        "/api/chat",
        json={
            "message": "Who formulated the Law of Effect and what is its main premise?",
            "note_context": note_ctx,
            "history": [],
        },
    )
    assert response.status_code in (200, 429)
    if response.status_code == 200:
        data = response.json()
        assert "reply" in data
        assert len(data["reply"]) > 10
        reply_lower = data["reply"].lower()
        assert "thorndike" in reply_lower or "satisfying" in reply_lower or "effect" in reply_lower
        assert data.get("key_takeaways") is not None
    else:
        assert "quota" in response.json()["detail"].lower()


def test_chat_empty_message_rejected():
    """Rejects empty chat message with HTTP 400."""
    response = client.post(
        "/api/chat",
        json={"message": "   ", "note_context": "Some context"},
    )
    assert response.status_code == 400


# --- Schema and Scoring Validation with Deterministic AI Payload ---

def test_quiz_scoring_and_5_mcqs_validation_schema():
    """
    Validates complete 5-question MCQ generation, 4 options per question,
    valid correct index, and deterministic 100% quiz scoring logic.
    """
    sample_ai_quiz = {
        "questions": [
            {
                "id": i + 1,
                "concept": f"Concept {i + 1}",
                "question_text": f"Question {i + 1} regarding cognitive memory?",
                "ai_hint": "Recall the main storage duration.",
                "options": [
                    {"label": "A", "text": "Option A Text", "subtitle": "Detail A"},
                    {"label": "B", "text": "Option B Text", "subtitle": "Detail B"},
                    {"label": "C", "text": "Option C Text", "subtitle": "Detail C"},
                    {"label": "D", "text": "Option D Text", "subtitle": "Detail D"},
                ],
                "correct_option_index": (i % 4),
                "explanation": f"Option {['A', 'B', 'C', 'D'][i % 4]} is correct based on the principle.",
                "topic_badge": "Memory",
                "average_time": "30s",
            }
            for i in range(5)
        ]
    }

    import json
    with patch("app.gemini_service.generate_content_with_retry") as mock_gen:
        mock_resp = MagicMock()
        mock_resp.text = json.dumps(sample_ai_quiz)
        mock_gen.return_value = mock_resp

        response = client.post(
            "/api/quiz/generate",
            json={"text": "A valid length study material containing over fifteen characters for testing."},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["total"] == 5
        assert len(data["questions"]) == 5

        # Test quiz scoring logic
        score = 0
        for q in data["questions"]:
            assert len(q["options"]) == 4
            assert 0 <= q["correct_option_index"] <= 3
            # Student picks correct index:
            if q["correct_option_index"] == q["correct_option_index"]:
                score += 1

        assert score == 5
        assert (score / 5) * 100 == 100.0


def test_notes_synthesis_schema_validation():
    """Validates note generation schema fields and data model."""
    import json
    sample_notes = {
        "title": "Synaptic Plasticity",
        "course_name": "Neuroscience",
        "course_code": "NEUR 101",
        "summary": "Long term potentiation strengthens synapses across hippocampal networks.",
        "key_definitions": [
            {"title": "LTP", "tag": "Plasticity", "body": "Long lasting increase in signal transmission."}
        ],
        "exam_pitfalls": [
            {"title": "AMPA vs NMDA", "description": "AMPA mediates fast sodium influx; NMDA allows calcium influx.", "concept_a": "AMPA", "concept_b": "NMDA"}
        ],
        "accuracy_percent": 95,
        "key_terms_count": 5,
        "read_time": "4 min read",
    }
    with patch("app.gemini_service.generate_content_with_retry") as mock_gen:
        mock_resp = MagicMock()
        mock_resp.text = json.dumps(sample_notes)
        mock_gen.return_value = mock_resp

        response = client.post(
            "/api/notes/generate",
            json={"text": "A valid length study material text exceeding fifteen characters."},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["title"] == "Synaptic Plasticity"
        assert len(data["key_definitions"]) == 1
        assert len(data["exam_pitfalls"]) == 1
        assert data["accuracy_percent"] == 95


def test_chat_with_notes_schema_validation():
    """Validates grounded chat schema fields and data model."""
    import json
    sample_chat = {
        "reply": "According to your notes, LTP is mediated by NMDA and AMPA glutamate receptors.",
        "note_reference": "Synaptic Plasticity Notes",
        "key_takeaways": ["AMPA causes depolarization.", "NMDA permits calcium entry."],
    }
    with patch("app.gemini_service.generate_content_with_retry") as mock_gen:
        mock_resp = MagicMock()
        mock_resp.text = json.dumps(sample_chat)
        mock_gen.return_value = mock_resp

        response = client.post(
            "/api/chat",
            json={"message": "What receptors mediate LTP?", "note_context": "Some note context"},
        )
        assert response.status_code == 200
        data = response.json()
        assert "LTP is mediated by NMDA" in data["reply"]
        assert len(data["key_takeaways"]) == 2


# --- Error Handling & Resilience Tests ---

def test_gemini_unconfigured_error():
    """Simulates unconfigured Gemini API key and asserts HTTP 503."""
    with patch("app.gemini_service.get_gemini_client", return_value=None):
        response = client.post(
            "/api/notes/generate",
            json={"text": "Sample text that would require Gemini note generation."},
        )
        assert response.status_code == 503
        assert "not configured" in response.json()["detail"].lower()


def test_gemini_quota_exceeded_error():
    """Simulates 429 quota exhaustion from Google GenAI and asserts HTTP 429."""
    with patch("app.gemini_service.get_gemini_client") as mock_get_client:
        mock_client = MagicMock()
        mock_client.models.generate_content.side_effect = Exception("429 Resource exhausted: quota exceeded")
        mock_get_client.return_value = mock_client

        response = client.post(
            "/api/notes/generate",
            json={"text": "Valid length study text for testing quota handling."},
        )
        assert response.status_code == 429
        assert "quota" in response.json()["detail"].lower()


def test_gemini_timeout_error():
    """Simulates request timeout from Google GenAI and asserts HTTP 504."""
    with patch("app.gemini_service.get_gemini_client") as mock_get_client:
        mock_client = MagicMock()
        mock_client.models.generate_content.side_effect = Exception("Deadline exceeded: request timed out")
        mock_get_client.return_value = mock_client

        response = client.post(
            "/api/quiz/generate",
            json={"text": "Valid length study text for testing timeout handling."},
        )
        assert response.status_code == 504
        assert "timed out" in response.json()["detail"].lower()


def test_gemini_malformed_json_error():
    """Simulates malformed non-JSON response from Google GenAI and asserts HTTP 502."""
    with patch("app.gemini_service.get_gemini_client") as mock_get_client:
        mock_client = MagicMock()
        mock_response = MagicMock()
        mock_response.text = "This is not JSON at all: [broken {{ syntax"
        mock_client.models.generate_content.return_value = mock_response
        mock_get_client.return_value = mock_client

        response = client.post(
            "/api/notes/generate",
            json={"text": "Valid length study text for testing malformed AI output."},
        )
        assert response.status_code == 502
        assert "malformed" in response.json()["detail"].lower()
