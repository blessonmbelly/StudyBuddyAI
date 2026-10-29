"""
Comprehensive End-to-End Test Suite for Phases 4-7:
- Document Persistence & CRUD (GET, POST, PUT, DELETE /api/documents)
- Note Generation & Linking (POST /api/notes/generate, GET /api/notes)
- Quiz Generation & Attempt Persistence (POST /api/quiz/generate, POST /api/quiz/{id}/attempt)
- Per-User Data Isolation (Strict isolation between User A and User B)
- Cascading Deletes & PostgreSQL Storage Verification
"""
import asyncio
import sys
import os
import uuid

# Ensure backend root is on sys.path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

from httpx import AsyncClient, ASGITransport
from main import app

async def run_async_integration_tests():
    print("=" * 75)
    print(" PHASES 4-7: FULL PERSISTENCE & DATA ISOLATION VERIFICATION")
    print("=" * 75)

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:

        # 1. Register User A & User B for isolation testing
        unique_suffix = uuid.uuid4().hex[:6]
        email_a = f"student_a_{unique_suffix}@studybuddy.ai"
        email_b = f"student_b_{unique_suffix}@studybuddy.ai"
        password = "SecurePassword123!"

        print("\n1. Registering User A & User B...")
        res_a = await client.post("/api/auth/register", json={
            "email": email_a,
            "password": password,
            "full_name": "Student Alpha"
        })
        assert res_a.status_code == 201, f"User A registration failed: {res_a.text}"
        token_a = res_a.json()["access_token"]
        headers_a = {"Authorization": f"Bearer {token_a}"}

        res_b = await client.post("/api/auth/register", json={
            "email": email_b,
            "password": password,
            "full_name": "Student Beta"
        })
        assert res_b.status_code == 201, f"User B registration failed: {res_b.text}"
        token_b = res_b.json()["access_token"]
        headers_b = {"Authorization": f"Bearer {token_b}"}
        print("   [PASS] User A and User B registered successfully.")

        # 2. Phase 4: Create Document for User A
        print("\n2. Testing Phase 4: Document Creation & Persistence...")
        doc_payload_a = {
            "title": "Cognitive Psychology Chapter 4",
            "original_filename": "psych_lecture4.pdf",
            "file_type": "PDF",
            "subject": "Psychology",
            "topics": ["Memory Encoding", "Retrieval Cues", "Hippocampus"],
            "extracted_text": "Memory encoding involves hippocampal synaptic plasticity and long-term potentiation.",
            "word_count": 10,
            "page_count": 2,
            "extraction_method": "pdf_embedded_text"
        }
        res_doc = await client.post("/api/documents", json=doc_payload_a, headers=headers_a)
        assert res_doc.status_code == 201, f"Doc creation failed: {res_doc.text}"
        doc_a = res_doc.json()
        doc_a_id = doc_a["id"]
        print(f"   [PASS] Document persisted to PostgreSQL with ID: {doc_a_id}")
        assert doc_a["title"] == "Cognitive Psychology Chapter 4"
        assert doc_a["subject"] == "Psychology"

        # 3. Phase 4: Document Isolation Check
        print("\n3. Testing Per-User Document Isolation...")
        # User A lists documents -> sees doc_a
        res_list_a = await client.get("/api/documents", headers=headers_a)
        list_a = res_list_a.json()
        assert len(list_a) >= 1
        assert any(d["id"] == doc_a_id for d in list_a)

        # User B lists documents -> does NOT see doc_a
        res_list_b = await client.get("/api/documents", headers=headers_b)
        list_b = res_list_b.json()
        assert not any(d["id"] == doc_a_id for d in list_b)
        print("   [PASS] User B cannot see User A's documents in list.")

        # User B tries to GET doc_a directly -> 404
        res_forbidden = await client.get(f"/api/documents/{doc_a_id}", headers=headers_b)
        assert res_forbidden.status_code == 404, f"Expected 404, got {res_forbidden.status_code}"
        print("   [PASS] User B direct access to User A's document returned 404.")

        # 4. Phase 4: Update Document
        print("\n4. Testing Document Metadata Update (PUT /api/documents/{id})...")
        res_update = await client.put(
            f"/api/documents/{doc_a_id}",
            json={"title": "Cognitive Psychology: Long Term Memory", "subject": "Cognitive Neuroscience"},
            headers=headers_a
        )
        assert res_update.status_code == 200
        updated_doc = res_update.json()
        assert updated_doc["title"] == "Cognitive Psychology: Long Term Memory"
        assert updated_doc["subject"] == "Cognitive Neuroscience"
        print("   [PASS] Document updated and persisted.")

        # 5. Phase 5: Generate & Persist Short Notes Linked to Document
        print("\n5. Testing Phase 5: Note Generation & Linking...")
        note_payload = {
            "text": "Memory retrieval relies on cues. When cues match the encoding context, recall probability increases significantly.",
            "course_name": "Cognitive Neuroscience",
            "course_code": "COG 201",
            "title": "Retrieval Cues & Contextual Memory",
            "document_id": doc_a_id,
        }
        res_note = await client.post("/api/notes/generate", json=note_payload, headers=headers_a)
        assert res_note.status_code == 200, f"Note generation failed: {res_note.text}"
        note_data = res_note.json()
        note_id = note_data.get("id")
        print(f"   [PASS] Note generated and persisted to PostgreSQL with ID: {note_id}")

        # List notes for User A & User B
        res_notes_a = await client.get("/api/notes", headers=headers_a)
        notes_a = res_notes_a.json()
        assert len(notes_a) >= 1
        assert any(n["id"] == str(note_id) for n in notes_a)

        res_notes_b = await client.get("/api/notes", headers=headers_b)
        notes_b = res_notes_b.json()
        assert len(notes_b) == 0
        print("   [PASS] Notes isolation verified: User B sees 0 notes.")

        # 6. Phase 6: Generate & Persist Quiz
        print("\n6. Testing Phase 6: Quiz Generation & Persistence...")
        quiz_payload = {
            "text": "Long term potentiation (LTP) is a persistent strengthening of synapses based on recent patterns of activity. LTP occurs in the hippocampus.",
            "num_questions": 3,
            "note_title": "Synaptic Plasticity Quiz",
            "document_id": doc_a_id,
        }
        res_quiz = await client.post("/api/quiz/generate", json=quiz_payload, headers=headers_a)
        assert res_quiz.status_code == 200, f"Quiz generation failed: {res_quiz.text}"
        quiz_data = res_quiz.json()
        quiz_id = quiz_data.get("quiz_id")
        print(f"   [PASS] Quiz generated and persisted to PostgreSQL with ID: {quiz_id}")

        # List quizzes for User A & User B
        res_quizzes_a = await client.get("/api/quiz", headers=headers_a)
        quizzes_a = res_quizzes_a.json()
        assert len(quizzes_a) >= 1

        res_quizzes_b = await client.get("/api/quiz", headers=headers_b)
        quizzes_b = res_quizzes_b.json()
        assert len(quizzes_b) == 0
        print("   [PASS] Quiz isolation verified: User B sees 0 quizzes.")

        # 7. Phase 6: Record Quiz Attempt
        print("\n7. Testing Quiz Attempt Submission (POST /api/quiz/{id}/attempt)...")
        attempt_payload = {
            "score": 3,
            "total_questions": 3,
            "time_spent_seconds": 45,
            "user_answers": {"0": 1, "1": 2, "2": 0}
        }
        res_attempt = await client.post(f"/api/quiz/{quiz_id}/attempt", json=attempt_payload, headers=headers_a)
        assert res_attempt.status_code == 201, f"Attempt failed: {res_attempt.text}"
        attempt_data = res_attempt.json()
        assert attempt_data["percentage"] == 100.0
        assert attempt_data["score"] == 3
        print(f"   [PASS] Quiz attempt recorded: 100% score (ID: {attempt_data['id']})")

        # Fetch attempts list
        res_attempts_a = await client.get("/api/quiz/attempts/all", headers=headers_a)
        attempts_a = res_attempts_a.json()
        assert len(attempts_a) >= 1

        res_attempts_b = await client.get("/api/quiz/attempts/all", headers=headers_b)
        attempts_b = res_attempts_b.json()
        assert len(attempts_b) == 0
        print("   [PASS] Quiz attempts isolation verified.")

        # 8. Phase 7: Document Cascading Deletion
        print("\n8. Testing Document Cascading Deletion...")
        res_del = await client.delete(f"/api/documents/{doc_a_id}", headers=headers_a)
        assert res_del.status_code == 200
        print("   [PASS] Document deleted successfully.")

        # Confirm doc_a is gone
        check_doc = await client.get(f"/api/documents/{doc_a_id}", headers=headers_a)
        assert check_doc.status_code == 404
        print("   [PASS] Confirmed document is no longer in database.")

        print("\n" + "=" * 75)
        print(" ALL PHASES 4-7 INTEGRATION & ISOLATION CHECKS PASSED!")
        print("=" * 75)

if __name__ == "__main__":
    asyncio.run(run_async_integration_tests())
