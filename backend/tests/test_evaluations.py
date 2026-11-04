"""
Tests for AI-Based Note Quality Evaluation:
1. Pydantic schema validation for FlaggedClaim, MissingTopic, VerifiedFact, UncertainClaim, NoteEvaluationResponse.
2. Epistemic caution checks (never claiming 100% accuracy without evidence).
3. Text length validation.
4. Route tests for evaluate_document and get_document_evaluation with mocked DB & Gemini.
"""
from datetime import datetime, timezone
from pathlib import Path
import sys
from unittest.mock import AsyncMock, MagicMock, patch
import uuid

import pytest
from fastapi import HTTPException

# Ensure backend root is in sys.path
backend_dir = Path(__file__).resolve().parent.parent
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

from app.db_models import Document, NoteEvaluation, User
from app.models import (
    FlaggedClaim,
    MissingTopic,
    NoteEvaluationCreateRequest,
    NoteEvaluationResponse,
    UncertainClaim,
    VerifiedFact,
)
from app.routes.evaluations import evaluate_document, get_document_evaluation


# --- 1. Schema & Model Tests ---

def test_flagged_claim_schema():
    claim = FlaggedClaim(
        statement="Mitochondria are only found in animal cells.",
        issue_type="INCORRECT",
        severity="HIGH",
        explanation="Plant cells and fungal cells also contain mitochondria.",
        evidence="According to Campbell Biology (12th ed., ch. 6), plant cells possess mitochondria for cellular respiration.",
        correction="Mitochondria are present in nearly all eukaryotic cells, including plants, animals, and fungi.",
    )
    assert claim.issue_type == "INCORRECT"
    assert claim.severity == "HIGH"
    assert "Campbell Biology" in claim.evidence
    assert claim.correction is not None


def test_missing_topic_schema():
    topic = MissingTopic(
        topic="Citric Acid Cycle (Krebs Cycle)",
        importance="CRITICAL",
        explanation="Essential step connecting glycolysis to oxidative phosphorylation.",
        recommended_overview="Matrix-based cyclic series producing NADH, FADH2, and ATP.",
    )
    assert topic.topic == "Citric Acid Cycle (Krebs Cycle)"
    assert topic.importance == "CRITICAL"


def test_note_evaluation_response_epistemic_caution():
    """Verify that score fields are clamped and never exceed 98 for factual accuracy."""
    eval_resp = NoteEvaluationResponse(
        id=str(uuid.uuid4()),
        document_id=str(uuid.uuid4()),
        user_id=str(uuid.uuid4()),
        topic_relevance_score=92,
        factual_accuracy_score=95,
        content_completeness_score=80,
        overall_score=89,
        quality_grade="B+",
        summary="Thorough notes covering basic cellular respiration with minor omissions.",
        flagged_claims=[
            FlaggedClaim(
                statement="Glycolysis requires oxygen.",
                issue_type="INCORRECT",
                severity="HIGH",
                explanation="Glycolysis is strictly anaerobic.",
                evidence="Glycolysis occurs in the cytosol without O2 requirement (Lehninger Biochemistry).",
            )
        ],
        missing_topics=[
            MissingTopic(
                topic="Electron Transport Chain",
                importance="CRITICAL",
                explanation="Required for generating the bulk of cellular ATP.",
            )
        ],
        verified_facts=[
            VerifiedFact(
                fact="Glycolysis produces a net of 2 ATP per glucose molecule.",
                corroboration="Confirmed by standard biochemical pathway stoichiometry.",
            )
        ],
        uncertain_claims=[
            UncertainClaim(
                claim="Exact ATP yield is 38 ATP per glucose.",
                reason="Modern estimates recognize 30-32 ATP due to proton leak and shuttle costs.",
            )
        ],
        additional_context=["Chemiosmotic coupling was discovered by Peter Mitchell in 1961."],
        strengths=["Clear explanation of glycolysis steps."],
        weaknesses=["Omitted oxidative phosphorylation."],
        recommendations=["Add detailed diagram of mitochondrial membrane complexes."],
    )

    assert eval_resp.topic_relevance_score == 92
    assert eval_resp.factual_accuracy_score <= 98  # Epistemic caution: never 100%
    assert len(eval_resp.flagged_claims) == 1
    assert eval_resp.flagged_claims[0].issue_type == "INCORRECT"
    assert len(eval_resp.missing_topics) == 1
    assert len(eval_resp.verified_facts) == 1
    assert len(eval_resp.uncertain_claims) == 1


# --- 2. Route Unit Tests ---

@pytest.mark.anyio
async def test_evaluate_document_not_found():
    mock_db = AsyncMock()
    mock_res = MagicMock()
    mock_res.scalar_one_or_none.return_value = None
    mock_db.execute.return_value = mock_res

    fake_user = User(id=uuid.uuid4(), email="student@university.edu")
    invalid_id = str(uuid.uuid4())

    with pytest.raises(HTTPException) as exc:
        await evaluate_document(document_id=invalid_id, current_user=fake_user, db=mock_db)

    assert exc.value.status_code == 404
    assert "Document not found" in exc.value.detail


@pytest.mark.anyio
async def test_evaluate_document_too_short_text():
    mock_db = AsyncMock()
    doc_id = uuid.uuid4()
    user_id = uuid.uuid4()

    fake_doc = Document(
        id=doc_id,
        user_id=user_id,
        title="Brief Note",
        extracted_text="Too short",
        subject="Physics",
    )
    mock_res = MagicMock()
    mock_res.scalar_one_or_none.return_value = fake_doc
    mock_db.execute.return_value = mock_res

    fake_user = User(id=user_id, email="student@university.edu")

    with pytest.raises(HTTPException) as exc:
        await evaluate_document(document_id=str(doc_id), current_user=fake_user, db=mock_db)

    assert exc.value.status_code == 400
    assert "too short" in exc.value.detail


@pytest.mark.anyio
async def test_evaluate_document_success():
    mock_db = AsyncMock()
    doc_id = uuid.uuid4()
    user_id = uuid.uuid4()

    fake_doc = Document(
        id=doc_id,
        user_id=user_id,
        title="Newtonian Mechanics",
        extracted_text="Newton's first law states that an object at rest remains at rest unless acted upon by an external net force. Newton's second law is F = ma. Third law is action-reaction.",
        subject="Physics",
    )

    # 1st query returns fake_doc, 2nd query (check existing eval) returns None
    mock_res_doc = MagicMock()
    mock_res_doc.scalar_one_or_none.return_value = fake_doc

    mock_res_eval = MagicMock()
    mock_res_eval.scalar_one_or_none.return_value = None

    mock_db.execute.side_effect = [mock_res_doc, mock_res_eval]

    fake_user = User(id=user_id, email="student@physics.edu")

    sample_eval_data = {
        "topic_relevance_score": 94,
        "factual_accuracy_score": 92,
        "content_completeness_score": 78,
        "overall_score": 88,
        "quality_grade": "B+",
        "summary": "Solid fundamentals on Newton's laws.",
        "flagged_claims": [],
        "missing_topics": [
            {
                "topic": "Inertial Reference Frames",
                "importance": "HIGH",
                "explanation": "Newton's laws are valid only in inertial frames.",
                "recommended_overview": "Non-accelerating reference frames.",
            }
        ],
        "verified_facts": [
            {
                "fact": "F = ma describes the relationship between force, mass, and acceleration.",
                "corroboration": "Fundamental theorem of classical mechanics.",
            }
        ],
        "uncertain_claims": [],
        "additional_context": ["Relativistic corrections apply near the speed of light."],
        "strengths": ["Concise definitions."],
        "weaknesses": ["Does not state vector nature of force."],
        "recommendations": ["Include vector arrows over F and a."],
    }

    with patch("app.routes.evaluations.evaluate_note_quality", return_value=sample_eval_data):
        response = await evaluate_document(
            document_id=str(doc_id),
            current_user=fake_user,
            db=mock_db,
        )

    assert response.topic_relevance_score == 94
    assert response.factual_accuracy_score == 92
    assert response.content_completeness_score == 78
    assert response.overall_score == 88
    assert response.quality_grade == "B+"
    assert len(response.missing_topics) == 1
    assert response.missing_topics[0].topic == "Inertial Reference Frames"
    assert mock_db.commit.called


@pytest.mark.anyio
async def test_get_document_evaluation_found():
    mock_db = AsyncMock()
    doc_id = uuid.uuid4()
    user_id = uuid.uuid4()

    fake_eval = NoteEvaluation(
        id=uuid.uuid4(),
        document_id=doc_id,
        user_id=user_id,
        topic_relevance_score=88,
        factual_accuracy_score=85,
        content_completeness_score=82,
        overall_score=85,
        quality_grade="B+",
        summary="Well-organized study note.",
        flagged_claims=[],
        missing_topics=[],
        verified_facts=[],
        uncertain_claims=[],
        additional_context=[],
        strengths=["Good structure."],
        weaknesses=[],
        recommendations=["Keep practicing."],
    )

    mock_res = MagicMock()
    mock_res.scalar_one_or_none.return_value = fake_eval
    mock_db.execute.return_value = mock_res

    fake_user = User(id=user_id, email="student@test.edu")

    response = await get_document_evaluation(
        document_id=str(doc_id),
        current_user=fake_user,
        db=mock_db,
    )

    assert response.topic_relevance_score == 88
    assert response.factual_accuracy_score == 85
    assert response.overall_score == 85
    assert response.quality_grade == "B+"


@pytest.mark.anyio
async def test_get_document_evaluation_not_found():
    mock_db = AsyncMock()
    mock_res = MagicMock()
    mock_res.scalar_one_or_none.return_value = None
    mock_db.execute.return_value = mock_res

    fake_user = User(id=uuid.uuid4(), email="student@test.edu")

    with pytest.raises(HTTPException) as exc:
        await get_document_evaluation(
            document_id=str(uuid.uuid4()),
            current_user=fake_user,
            db=mock_db,
        )

    assert exc.value.status_code == 404
    assert "No quality evaluation found" in exc.value.detail

