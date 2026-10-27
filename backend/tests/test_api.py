import io
import pytest
from fastapi.testclient import TestClient
import docx

import sys
from pathlib import Path
# Add backend directory to sys.path so app imports work
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from main import app

client = TestClient(app)

def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert "gemini_configured" in data
    assert "version" in data

def test_extract_txt_file():
    txt_content = b"Ebbinghaus Forgetting Curve shows memory decay over time without spaced repetition."
    response = client.post(
        "/api/files/extract",
        files={"file": ("lecture_note.txt", io.BytesIO(txt_content), "text/plain")}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert data["file_type"] == "TXT"
    assert "Ebbinghaus" in data["extracted_text"]
    assert data["word_count"] > 0

def test_extract_docx_file():
    doc = docx.Document()
    doc.add_paragraph("Consolidation transforms labile memories into enduring neural traces.")
    docx_io = io.BytesIO()
    doc.save(docx_io)
    docx_io.seek(0)

    response = client.post(
        "/api/files/extract",
        files={"file": ("notes.docx", docx_io, "application/vnd.openxmlformats-officedocument.wordprocessingml.document")}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert data["file_type"] == "DOCX"
    assert "Consolidation" in data["extracted_text"]

def test_extract_empty_file_fails():
    response = client.post(
        "/api/files/extract",
        files={"file": ("empty.txt", io.BytesIO(b""), "text/plain")}
    )
    assert response.status_code == 400
    assert "empty" in response.json()["detail"].lower()

def test_extract_unsupported_format_fails():
    response = client.post(
        "/api/files/extract",
        files={"file": ("app.exe", io.BytesIO(b"binary_junk"), "application/octet-stream")}
    )
    assert response.status_code == 400
    assert "unsupported" in response.json()["detail"].lower()

def test_generate_notes():
    sample_text = (
        "Sensory memory holds raw sensory stimuli for milliseconds to seconds. "
        "Short-term memory stores 7 plus or minus 2 items for 20-30 seconds. "
        "Consolidation by the hippocampus stabilizes these traces into long-term memory."
    )
    response = client.post(
        "/api/notes/generate",
        json={"text": sample_text, "course_code": "PSYC 201", "course_name": "Cognitive Psychology"}
    )
    assert response.status_code == 200
    data = response.json()
    assert "title" in data
    assert "summary" in data
    assert len(data["key_definitions"]) >= 1
    assert len(data["exam_pitfalls"]) >= 1
    assert data["raw_transcript"] == sample_text

def test_generate_notes_empty_fails():
    response = client.post(
        "/api/notes/generate",
        json={"text": "   "}
    )
    assert response.status_code == 400

def test_generate_quiz():
    sample_text = (
        "Sensory memory holds raw sensory stimuli for milliseconds to seconds. "
        "Short-term memory stores 7 plus or minus 2 items for 20-30 seconds. "
        "Consolidation by the hippocampus stabilizes these traces into long-term memory. "
        "Retrograde amnesia affects memories before trauma; anterograde prevents new memories."
    )
    response = client.post(
        "/api/quiz/generate",
        json={"text": sample_text, "num_questions": 5}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["total"] == 5
    assert len(data["questions"]) == 5
    for q in data["questions"]:
        assert len(q["options"]) == 4
        assert 0 <= q["correct_option_index"] <= 3
        assert len(q["explanation"]) > 0
        assert len(q["ai_hint"]) > 0

def test_chat_with_notes():
    note_ctx = "The Ebbinghaus Forgetting Curve shows memory retention drops sharply in the first 24 hours."
    response = client.post(
        "/api/chat",
        json={
            "message": "Why does memory decay so quickly without review?",
            "note_context": note_ctx,
            "history": []
        }
    )
    assert response.status_code == 200
    data = response.json()
    assert "reply" in data
    assert len(data["reply"]) > 10
