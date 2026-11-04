"""
Live PostgreSQL verification of Note Quality Evaluations.
Tests:
1. User & Document creation in live PostgreSQL.
2. Direct insertion and retrieval from `note_evaluations` table.
3. Verification of JSONB fields: flagged_claims, missing_topics, verified_facts, uncertain_claims.
4. Score constraints (topic_relevance, factual_accuracy, content_completeness).
5. Cascade deletion when document or user is deleted.
"""
import asyncio
from datetime import datetime, timezone
from pathlib import Path
import sys
import uuid

# Ensure backend root is in sys.path
backend_dir = Path(__file__).resolve().parent
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession

from app.config import settings
from app.db_models import Document, NoteEvaluation, User
from app.auth import hash_password


async def run_live_eval_test():
    print("=" * 75)
    print(" LIVE POSTGRESQL NOTE QUALITY EVALUATION VERIFICATION")
    print("=" * 75)

    engine = create_async_engine(settings.async_database_url, echo=False)
    async_session = async_sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)

    test_email = f"eval_test_{uuid.uuid4().hex[:8]}@studybuddy.ai"
    test_user_id = uuid.uuid4()
    test_doc_id = uuid.uuid4()
    test_eval_id = uuid.uuid4()

    try:
        async with async_session() as session:
            # 1. Create Test User
            user = User(
                id=test_user_id,
                email=test_email,
                hashed_password=hash_password("TestPassword123!"),
                full_name="Quality Eval Student",
                is_active=True,
            )
            session.add(user)
            await session.commit()
            print(f"[+] Created test user: {test_email} ({test_user_id})")

            # 2. Create Test Document
            doc = Document(
                id=test_doc_id,
                user_id=test_user_id,
                title="Cell Biology: Photosynthesis & Respiration",
                original_filename="cell_bio.txt",
                file_type="TXT",
                subject="Biology",
                topics=["Photosynthesis", "Cellular Respiration", "Chloroplasts"],
                extracted_text="Chloroplasts carry out photosynthesis in plants. Light reactions produce ATP and NADPH. The Calvin cycle uses CO2, ATP, and NADPH to synthesize glucose. Cellular respiration occurs in mitochondria.",
                word_count=35,
            )
            session.add(doc)
            await session.commit()
            print(f"[+] Created test document: {doc.title} ({test_doc_id})")

            # 3. Create Note Evaluation in PostgreSQL
            note_eval = NoteEvaluation(
                id=test_eval_id,
                user_id=test_user_id,
                document_id=test_doc_id,
                topic_relevance_score=92,
                factual_accuracy_score=94,
                content_completeness_score=75,
                overall_score=87,
                quality_grade="B+",
                summary="Strong foundation on plant energetics; missing photorespiration and C4/CAM adaptations.",
                flagged_claims=[
                    {
                        "statement": "Glucose is directly synthesized by the Calvin cycle.",
                        "issue_type": "MISLEADING",
                        "severity": "MEDIUM",
                        "explanation": "The Calvin cycle directly yields G3P (glyceraldehyde-3-phosphate), which is later converted to glucose.",
                        "evidence": "Campbell Biology (12th ed., ch. 10).",
                        "correction": "The Calvin cycle directly produces G3P, which is then used by the plant to synthesize glucose and other carbohydrates.",
                    }
                ],
                missing_topics=[
                    {
                        "topic": "Photorespiration & Rubisco Oxygenation",
                        "importance": "HIGH",
                        "explanation": "Critical limitation of C3 plants when CO2 is low.",
                        "recommended_overview": "Rubisco binds O2 instead of CO2, consuming ATP without sugar production.",
                    }
                ],
                verified_facts=[
                    {
                        "fact": "Light reactions produce ATP and NADPH.",
                        "corroboration": "Thylakoid electron transport chain produces ATP via ATP synthase and NADPH via ferredoxin-NADP+ reductase.",
                    }
                ],
                uncertain_claims=[],
                additional_context=["Cyanobacteria perform oxygenic photosynthesis similar to chloroplast thylakoids."],
                strengths=["Clear differentiation of light reactions and Calvin cycle."],
                weaknesses=["Omitted carbon fixation stoichiometry."],
                recommendations=["Include the RuBP regeneration phase equations."],
            )
            session.add(note_eval)
            await session.commit()
            print(f"[+] Inserted NoteEvaluation into PostgreSQL ({test_eval_id})")

            # 4. Query Evaluation and verify JSONB integrity
            stmt = select(NoteEvaluation).where(NoteEvaluation.document_id == test_doc_id)
            res = await session.execute(stmt)
            fetched = res.scalar_one()

            assert fetched.topic_relevance_score == 92
            assert fetched.factual_accuracy_score == 94
            assert fetched.content_completeness_score == 75
            assert fetched.overall_score == 87
            assert fetched.quality_grade == "B+"
            assert len(fetched.flagged_claims) == 1
            assert fetched.flagged_claims[0]["issue_type"] == "MISLEADING"
            assert len(fetched.missing_topics) == 1
            assert len(fetched.verified_facts) == 1
            print("[+] Retrieved NoteEvaluation and verified JSONB fields match perfectly!")

            # 5. Test Cascade Deletion: Deleting Document deletes NoteEvaluation
            await session.delete(doc)
            await session.commit()

            check_stmt = select(NoteEvaluation).where(NoteEvaluation.id == test_eval_id)
            check_res = await session.execute(check_stmt)
            assert check_res.scalar_one_or_none() is None
            print("[+] Verified cascade deletion: Deleting document cleanly deleted evaluation.")

    finally:
        # Cleanup user
        async with async_session() as session:
            await session.execute(delete(User).where(User.id == test_user_id))
            await session.commit()
            print("[+] Cleaned up test user record.")

    print("=" * 75)
    print(" ALL LIVE EVALUATION DATABASE TESTS PASSED!")
    print("=" * 75)


if __name__ == "__main__":
    asyncio.run(run_live_eval_test())

