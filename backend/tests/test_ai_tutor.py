from datetime import datetime, timezone
from pathlib import Path
import sys
from unittest.mock import MagicMock, patch
import uuid

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient

# Ensure backend root is in sys.path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from main import app
from app.auth import create_access_token
from app.db_models import ChatMessage, Conversation, Document, User
from app.gemini_service import (
    retrieve_relevant_document_chunks,
    answer_student_tutor_chat,
)
from app.models import HistoryMessage

client = TestClient(app)


# =============================================================================
# 1. UNIT TESTS: DOCUMENT CHUNKING & RELEVANT RETRIEVAL
# =============================================================================

def test_short_document_retrieval_returns_unaltered():
    """Documents under 3000 chars should be returned directly without chunking."""
    short_text = "Photosynthesis is the process by which green plants synthesize nutrients from carbon dioxide and water."
    result = retrieve_relevant_document_chunks(short_text, "What is photosynthesis?")
    assert result == short_text


def test_long_document_chunking_and_relevance_retrieval():
    """
    Long documents (>3000 chars) must be chunked and only the most relevant
    excerpts matching the student's query returned, preventing token overflow.
    """
    para1 = "Introduction to Operating Systems: An OS manages computer hardware and software resources. " * 25
    para2 = "Memory Management: Paging and segmentation allow virtual memory translation via page tables. TLB caches translations. " * 25
    para3 = "File Systems: Inodes store file metadata such as permissions, file size, and data block pointers. " * 25
    para4 = "Process Synchronization: Mutexes, semaphores, and condition variables prevent race conditions in critical sections. " * 25

    full_document = f"{para1}\n\n{para2}\n\n{para3}\n\n{para4}"
    assert len(full_document) > 8000  # Verify it's a long document

    query = "How do inodes work in file systems?"
    retrieved = retrieve_relevant_document_chunks(full_document, query, max_chunks=2)

    # Must contain relevant file system/inode text
    assert "Inodes store file metadata" in retrieved
    # Must be bounded in size, much smaller than full document
    assert len(retrieved) < len(full_document)
    assert "[Excerpt 1" in retrieved


def test_empty_or_whitespace_document_handling():
    """Empty or whitespace documents must return empty string safely without error."""
    assert retrieve_relevant_document_chunks("", "query") == ""
    assert retrieve_relevant_document_chunks("   ", "query") == ""


# =============================================================================
# 2. UNIT TESTS: AI TUTOR CHAT REASONING & DISTINCTION
# =============================================================================

@patch("app.gemini_service.generate_content_with_retry")
@patch("app.gemini_service.get_gemini_client")
def test_answer_student_tutor_chat_with_document(mock_client, mock_generate):
    """
    Verifies that AI Tutor uses document context, distinguishes note facts from
    broader knowledge, and returns structured response.
    """
    mock_client.return_value = MagicMock()
    mock_response = MagicMock()
    mock_response.text = '''{
        "reply": "From your notes: Mitochondria generate ATP through oxidative phosphorylation.\\n\\nBroader Analogy: Think of mitochondria as the power plant of a bustling city, converting raw fuel into electricity that keeps every appliance running.",
        "note_reference": "Mitochondrial Bioenergetics",
        "key_takeaways": [
            "ATP is generated along the inner mitochondrial membrane.",
            "Cristae maximize surface area for electron transport chains."
        ],
        "outside_knowledge_used": true
    }'''
    mock_generate.return_value = mock_response

    doc_text = "Mitochondria generate ATP through oxidative phosphorylation across the inner membrane."
    res = answer_student_tutor_chat(
        message="Can you explain mitochondria with an analogy?",
        document_context=doc_text,
        document_title="Cellular Biology Notes",
        subject="Biology",
    )

    assert "Mitochondria generate ATP" in res["reply"]
    assert "power plant" in res["reply"]
    assert res["note_reference"] == "Mitochondrial Bioenergetics"
    assert len(res["key_takeaways"]) == 2
    assert res["outside_knowledge_used"] is True


@patch("app.gemini_service.generate_content_with_retry")
@patch("app.gemini_service.get_gemini_client")
def test_answer_student_tutor_chat_general_session(mock_client, mock_generate):
    """
    Verifies that general AI Tutor conversation without a document works smoothly,
    providing general knowledge, examples, and study techniques.
    """
    mock_client.return_value = MagicMock()
    mock_response = MagicMock()
    mock_response.text = '''{
        "reply": "Newton's Second Law states that force equals mass times acceleration (F = ma). For instance, pushing a heavy car requires much more force than pushing a light bicycle to achieve the same speed.",
        "note_reference": "General Knowledge • AI Tutor",
        "key_takeaways": [
            "F = ma defines the relationship between force, mass, and acceleration.",
            "Acceleration is directly proportional to net force."
        ],
        "outside_knowledge_used": true
    }'''
    mock_generate.return_value = mock_response

    res = answer_student_tutor_chat(
        message="Explain Newton's second law with an everyday example.",
        document_context="",
    )

    assert "Newton's Second Law" in res["reply"]
    assert "F = ma" in res["reply"]
    assert res["note_reference"] == "General Knowledge • AI Tutor"
    assert res["outside_knowledge_used"] is True


# =============================================================================
# 3. ROUTE TESTS: CONVERSATIONS, AUTHORIZATION & PERSISTENCE
# =============================================================================

@pytest.mark.anyio
async def test_chat_requires_authentication():
    """Protected chat conversation routes must reject unauthenticated requests."""
    res = client.get("/api/chat/conversations")
    assert res.status_code == 401

    res_post = client.post("/api/chat/conversations", json={"title": "Test Chat"})
    assert res_post.status_code == 401

    res_msg = client.post("/api/chat/message", json={"message": "Hello"})
    assert res_msg.status_code == 401


def test_legacy_chat_endpoint_works_unauthenticated():
    """Legacy POST /api/chat remains accessible for backwards compatibility."""
    with patch("app.routes.chat.answer_student_chat") as mock_answer:
        mock_answer.return_value = {
            "reply": "StudyBuddy AI Tutor response.",
            "note_reference": "General Knowledge • AI Tutor",
            "key_takeaways": ["Study active recall regularly."],
            "outside_knowledge_used": True,
        }
        res = client.post("/api/chat", json={"message": "What is spaced repetition?"})
        assert res.status_code == 200
        data = res.json()
        assert "StudyBuddy AI Tutor response" in data["reply"]

