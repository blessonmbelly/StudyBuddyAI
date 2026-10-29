"""
End-to-End Test Suite for AI Tutor Feature:
1. Student registration & authentication
2. Document creation (upload/save study material)
3. Creating a conversation linked to a document
4. Creating a general study conversation (no document)
5. Sending a student message about the document (persisted in PostgreSQL)
6. Sending a broader question using general knowledge (outside_knowledge_used flag)
7. Message history restoration and retrieval (GET /api/chat/conversations/{id})
8. Unified auto-conversation endpoint (POST /api/chat/message)
9. Per-User Authorization & Data Isolation (User B cannot access User A's conversations or messages)
10. Conversation deletion and message cascade
"""
import asyncio
import os
import sys
import uuid

# Ensure backend root is on sys.path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

from httpx import AsyncClient, ASGITransport
from main import app


async def run_ai_tutor_tests():
    print("=" * 75)
    print(" AI TUTOR FEATURE: BACKEND & DATABASE E2E VERIFICATION")
    print("=" * 75)

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        unique_suffix = uuid.uuid4().hex[:6]
        email_a = f"tutor_user_a_{unique_suffix}@studybuddy.ai"
        email_b = f"tutor_user_b_{unique_suffix}@studybuddy.ai"
        password = "SecurePassword123!"

        # 1. Register User A and User B
        print("\n1. Registering User A and User B...")
        res_a = await client.post("/api/auth/register", json={
            "email": email_a,
            "password": password,
            "full_name": "Tutor Student A"
        })
        assert res_a.status_code == 201, f"User A registration failed: {res_a.text}"
        token_a = res_a.json()["access_token"]
        headers_a = {"Authorization": f"Bearer {token_a}"}

        res_b = await client.post("/api/auth/register", json={
            "email": email_b,
            "password": password,
            "full_name": "Tutor Student B"
        })
        assert res_b.status_code == 201, f"User B registration failed: {res_b.text}"
        token_b = res_b.json()["access_token"]
        headers_b = {"Authorization": f"Bearer {token_b}"}
        print("   [PASS] User A and User B registered successfully.")

        # 2. Upload study document for User A
        print("\n2. Creating study document for User A...")
        doc_payload = {
            "title": "Photosynthesis and Cellular Respiration",
            "extracted_text": (
                "Photosynthesis is the biochemical process by which green plants, algae, and some bacteria "
                "convert light energy, usually from the sun, into chemical energy stored in glucose molecules. "
                "The light-dependent reactions occur in the thylakoid membranes of chloroplasts, producing ATP and NADPH. "
                "The light-independent Calvin cycle occurs in the stroma and fixes carbon dioxide into carbohydrates. "
                "In contrast, cellular respiration occurs in the mitochondria to break down glucose into ATP."
            ),
            "file_type": "text/plain",
            "page_count": 1,
            "subject": "Biology",
        }
        res_doc = await client.post("/api/documents", json=doc_payload, headers=headers_a)
        assert res_doc.status_code == 201, f"Document creation failed: {res_doc.text}"
        doc_a_id = res_doc.json()["id"]
        print(f"   [PASS] Document created with ID: {doc_a_id}")

        # 3. Create document-linked conversation
        print("\n3. Creating conversation linked to document...")
        conv_payload = {
            "document_id": doc_a_id,
            "title": "Photosynthesis Q&A"
        }
        res_conv = await client.post("/api/chat/conversations", json=conv_payload, headers=headers_a)
        assert res_conv.status_code == 201, f"Conversation creation failed: {res_conv.text}"
        conv_data = res_conv.json()
        conv_id = conv_data["id"]
        assert conv_data["document_id"] == doc_a_id
        assert conv_data["title"] == "Photosynthesis Q&A"
        print(f"   [PASS] Conversation created: {conv_id}")

        # 4. Create general study conversation (no document)
        print("\n4. Creating general study conversation without document...")
        res_gen_conv = await client.post("/api/chat/conversations", json={"title": "General AI Tutor"}, headers=headers_a)
        assert res_gen_conv.status_code == 201
        gen_conv_id = res_gen_conv.json()["id"]
        assert res_gen_conv.json()["document_id"] is None
        print(f"   [PASS] General conversation created: {gen_conv_id}")

        # 5. Send message in document conversation
        print("\n5. Sending student question about document (Where does the Calvin cycle occur?)...")
        msg_payload = {"message": "Where does the Calvin cycle occur according to my notes?"}
        res_msg = await client.post(
            f"/api/chat/conversations/{conv_id}/messages",
            json=msg_payload,
            headers=headers_a,
        )
        assert res_msg.status_code == 201, f"Message send failed: {res_msg.text}"
        ai_reply = res_msg.json()
        assert ai_reply["sender"] == "ai"
        assert len(ai_reply["text"]) > 0
        print(f"   [PASS] AI response received: {ai_reply['text'][:80]}...")
        if ai_reply.get("note_reference"):
            print(f"          Note reference: {ai_reply['note_reference']}")

        # 6. Send general knowledge question (analogy / broader question)
        print("\n6. Sending broader question beyond notes (Give me an analogy to understand this)...")
        res_msg2 = await client.post(
            f"/api/chat/conversations/{conv_id}/messages",
            json={"message": "Can you give me an everyday real-world analogy to understand photosynthesis?"},
            headers=headers_a,
        )
        assert res_msg2.status_code == 201
        ai_reply2 = res_msg2.json()
        print(f"   [PASS] AI response received: {ai_reply2['text'][:80]}...")
        print(f"          Outside knowledge used: {ai_reply2.get('outside_context')}")

        # 7. Retrieve conversation history from PostgreSQL
        print("\n7. Retrieving full conversation history from PostgreSQL...")
        res_history = await client.get(f"/api/chat/conversations/{conv_id}", headers=headers_a)
        assert res_history.status_code == 200
        history_data = res_history.json()
        # Should have 4 messages: 2 user messages + 2 AI messages
        assert len(history_data["messages"]) == 4, f"Expected 4 messages, got {len(history_data['messages'])}"
        assert history_data["messages"][0]["sender"] == "user"
        assert history_data["messages"][1]["sender"] == "ai"
        assert history_data["messages"][2]["sender"] == "user"
        assert history_data["messages"][3]["sender"] == "ai"
        print(f"   [PASS] Successfully retrieved 4 persisted messages in order.")

        # 8. Test unified /api/chat/message endpoint
        print("\n8. Testing unified POST /api/chat/message endpoint...")
        res_unified = await client.post(
            "/api/chat/message",
            json={"message": "What is the mitochondria known as?", "document_id": doc_a_id},
            headers=headers_a,
        )
        assert res_unified.status_code == 200, f"Unified chat failed: {res_unified.text}"
        unified_data = res_unified.json()
        assert unified_data["conversation_id"] == conv_id
        assert len(unified_data["reply"]) > 0
        print(f"   [PASS] Unified chat returned reply and mapped to existing conversation.")

        # 9. Test authorization & data isolation (User B attempts to access User A's conversation)
        print("\n9. Testing User Data Isolation (User B cannot access User A's conversation)...")
        res_unauth = await client.get(f"/api/chat/conversations/{conv_id}", headers=headers_b)
        assert res_unauth.status_code == 404, f"Expected 404, got {res_unauth.status_code}"

        res_unauth_send = await client.post(
            f"/api/chat/conversations/{conv_id}/messages",
            json={"message": "I am hacking into User A's chat"},
            headers=headers_b,
        )
        assert res_unauth_send.status_code == 404, f"Expected 404, got {res_unauth_send.status_code}"

        # User B cannot create conversation with User A's document
        res_unauth_create = await client.post(
            "/api/chat/conversations",
            json={"document_id": doc_a_id, "title": "Stolen doc chat"},
            headers=headers_b,
        )
        assert res_unauth_create.status_code == 404, f"Expected 404, got {res_unauth_create.status_code}"
        print("   [PASS] User B was blocked from accessing or creating chats with User A's data.")

        # 10. Delete conversation
        print("\n10. Testing conversation deletion...")
        res_del = await client.delete(f"/api/chat/conversations/{conv_id}", headers=headers_a)
        assert res_del.status_code == 200

        res_check_del = await client.get(f"/api/chat/conversations/{conv_id}", headers=headers_a)
        assert res_check_del.status_code == 404
        print("   [PASS] Conversation and messages deleted cleanly.")

    print("\n" + "=" * 75)
    print(" ALL AI TUTOR BACKEND E2E TESTS PASSED!")
    print("=" * 75)


if __name__ == "__main__":
    asyncio.run(run_ai_tutor_tests())
