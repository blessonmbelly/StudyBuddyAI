import asyncio
import io
import os
import sys
import uuid

sys.path.insert(0, os.path.dirname(__file__))

import pytest
from httpx import AsyncClient, ASGITransport
from main import app
from app.database import AsyncSessionLocal, engine
from app.auth import hash_password
from app.db_models import User, Document
from sqlalchemy import select, delete

async def test_multi_photo_scanning():
    print("===========================================================================")
    print(" MULTI-PHOTO SCANNING & BACKEND VERIFICATION")
    print("===========================================================================")
    
    # 1. Setup test user
    test_email = f"blesson_test_{uuid.uuid4().hex[:6]}@studybuddy.ai"
    test_password = "SecurePassword123!"
    test_name = "Blesson Belly"
    
    async with AsyncSessionLocal() as session:
        user = User(
            id=uuid.uuid4(),
            email=test_email,
            full_name=test_name,
            hashed_password=hash_password(test_password),
        )
        session.add(user)
        await session.commit()
        await session.refresh(user)
        user_id = user.id

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Login to obtain token
        login_res = await client.post(
            "/api/auth/login",
            json={"email": test_email, "password": test_password},
        )
        assert login_res.status_code == 200, f"Login failed: {login_res.text}"
        token = login_res.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        # Test 1: POST /api/files/extract-multiple with 2 text files (simulating OCR pages)
        print("1. Testing POST /api/files/extract-multiple with 2 pages in order...")
        page1_content = b"Photosynthesis occurs in chloroplasts. Light energy is captured by chlorophyll."
        page2_content = b"Cellular respiration occurs in mitochondria, breaking glucose down into ATP."
        
        files = [
            ("files", ("lecture_p1.txt", io.BytesIO(page1_content), "text/plain")),
            ("files", ("lecture_p2.txt", io.BytesIO(page2_content), "text/plain")),
        ]
        
        extract_res = await client.post("/api/files/extract-multiple", files=files, headers=headers)
        assert extract_res.status_code == 200, f"Extract multiple failed: {extract_res.text}"
        data = extract_res.json()
        assert data["page_count"] == 2, f"Expected page_count=2, got {data['page_count']}"
        assert "--- Page 1 (lecture_p1.txt) ---" in data["extracted_text"]
        assert "--- Page 2 (lecture_p2.txt) ---" in data["extracted_text"]
        # Check order: Page 1 must appear before Page 2
        p1_idx = data["extracted_text"].find("Page 1")
        p2_idx = data["extracted_text"].find("Page 2")
        assert p1_idx < p2_idx, "Page 1 must appear before Page 2"
        print(f"   [PASS] Multi-page extracted successfully. page_count={data['page_count']}, document_id={data['document_id']}")
        
        # Test 2: POST /api/files/organize with page_count
        print("2. Testing POST /api/files/organize with page_count=4...")
        combined_text = (
            "--- Page 1 ---\nIntroduction to organic chemistry.\n\n"
            "--- Page 2 ---\nAlkanes, alkenes and alkynes nomenclature.\n\n"
            "--- Page 3 ---\nFunctional groups and isomers.\n\n"
            "--- Page 4 ---\nReaction mechanisms and electron pushing."
        )
        org_res = await client.post(
            "/api/files/organize",
            json={
                "text": combined_text,
                "filename": "Chemistry_MultiScan_4_Pages",
                "page_count": 4,
            },
            headers=headers,
        )
        assert org_res.status_code == 200, f"Organize failed: {org_res.text}"
        org_doc_id = org_res.json()["document_id"]
        print(f"   [PASS] Text organized and saved with ID: {org_doc_id}")
        
        # Test 3: Verify documents in PostgreSQL with GET /api/documents
        print("3. Testing GET /api/documents to verify persistence and page_count...")
        docs_res = await client.get("/api/documents", headers=headers)
        assert docs_res.status_code == 200, f"Get documents failed: {docs_res.text}"
        user_docs = docs_res.json()
        assert len(user_docs) >= 2, f"Expected at least 2 documents, got {len(user_docs)}"
        
        # Verify page_counts are persisted in DB
        page_counts = [d["page_count"] for d in user_docs]
        assert 2 in page_counts, f"Expected a document with page_count=2, got {page_counts}"
        assert 4 in page_counts, f"Expected a document with page_count=4, got {page_counts}"
        print(f"   [PASS] Verified persisted documents have correct page_counts: {page_counts}")

    # Clean up test user and documents
    async with AsyncSessionLocal() as session:
        await session.execute(delete(Document).where(Document.user_id == user_id))
        await session.execute(delete(User).where(User.id == user_id))
        await session.commit()
    
    await engine.dispose()
    print("===========================================================================")
    print(" ALL MULTI-PHOTO SCANNING TESTS PASSED!")
    print("===========================================================================")

if __name__ == "__main__":
    asyncio.run(test_multi_photo_scanning())
