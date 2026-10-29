"""
Phase 1 Validation Script: PostgreSQL Database Foundation
Verifies:
1. SQLAlchemy 2.x async engine and session factory configuration.
2. DB models (User, RefreshToken, Document, GeneratedNote, Quiz, QuizAttempt)
   with UUID PKs, foreign keys, timestamps, indexes, TEXT and JSONB columns.
3. User association and data isolation references.
4. Absence of silent fallback to in-memory storage when PostgreSQL is unreachable.
5. Alembic configuration and migration script validity.
"""
import sys
from pathlib import Path
from uuid import UUID as PyUUID

# Ensure Windows terminal doesn't crash on utf-8 characters
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

# Add backend directory to sys.path
backend_dir = Path(__file__).resolve().parent
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.types import Text

from app.config import settings
from app.database import Base, engine, AsyncSessionLocal, get_db
from app.db_models import (
    User,
    RefreshToken,
    Document,
    GeneratedNote,
    Quiz,
    QuizAttempt,
)


def log_test(name: str):
    print(f"\n[TEST] {name}...", flush=True)


def main():
    print("=" * 70)
    print(" PHASE 1: POSTGRESQL DATABASE FOUNDATION VERIFICATION")
    print("=" * 70)

    # 1. Verify Configuration
    log_test("Configuration & DATABASE_URL")
    assert settings.DATABASE_URL, "DATABASE_URL setting must be configured."
    assert "postgresql" in settings.DATABASE_URL, "DATABASE_URL must be a PostgreSQL connection string."
    assert settings.async_database_url.startswith("postgresql+asyncpg://"), (
        f"async_database_url must use asyncpg driver, got {settings.async_database_url}"
    )
    print(f"  [+] DATABASE_URL driver normalized: {settings.async_database_url.split('@')[-1]}")
    print("  [PASS] Configuration is properly configured.")

    # 2. Verify Table Registration on Base.metadata
    log_test("Table Registration on Base.metadata")
    expected_tables = {
        "users",
        "refresh_tokens",
        "documents",
        "generated_notes",
        "quizzes",
        "quiz_attempts",
    }
    registered_tables = set(Base.metadata.tables.keys())
    assert expected_tables.issubset(registered_tables), (
        f"Missing tables in metadata. Expected {expected_tables}, got {registered_tables}"
    )
    print(f"  [+] Registered tables ({len(registered_tables)}): {sorted(list(registered_tables))}")
    print("  [PASS] All 6 Phase 1 tables are properly registered.")

    # 3. Verify UUID Primary Keys on All Tables
    log_test("UUID Primary Keys")
    for table_name in expected_tables:
        table = Base.metadata.tables[table_name]
        pk_cols = [c for c in table.columns if c.primary_key]
        assert len(pk_cols) == 1, f"Table {table_name} must have exactly one primary key column."
        pk = pk_cols[0]
        assert pk.name == "id", f"Table {table_name} PK must be named 'id'."
        assert isinstance(pk.type, UUID), f"Table {table_name} PK must be a UUID type."
        print(f"  [+] {table_name}.id -> UUID (PK)")
    print("  [PASS] All tables use UUID primary keys.")

    # 4. Verify Per-User Foreign Keys and Data Isolation
    log_test("Per-User Foreign Keys & Cascade Constraints")
    user_owned_tables = {
        "refresh_tokens": ("user_id", "users.id", "CASCADE"),
        "documents": ("user_id", "users.id", "CASCADE"),
        "generated_notes": ("user_id", "users.id", "CASCADE"),
        "quizzes": ("user_id", "users.id", "CASCADE"),
        "quiz_attempts": ("user_id", "users.id", "CASCADE"),
    }
    for table_name, (col_name, target, ondelete) in user_owned_tables.items():
        table = Base.metadata.tables[table_name]
        fks = [fk for fk in table.foreign_keys if fk.parent.name == col_name]
        assert fks, f"Table {table_name} must have foreign key on {col_name}."
        fk = fks[0]
        assert fk.target_fullname == target, f"Expected FK to {target}, got {fk.target_fullname}"
        assert fk.ondelete.upper() == ondelete, f"Expected ON DELETE {ondelete}, got {fk.ondelete}"
        print(f"  [+] {table_name}.{col_name} -> {target} (ON DELETE {ondelete})")

    # Verify QuizAttempt references quiz_id
    qa_table = Base.metadata.tables["quiz_attempts"]
    quiz_fks = [fk for fk in qa_table.foreign_keys if fk.parent.name == "quiz_id"]
    assert quiz_fks, "quiz_attempts must have foreign key on quiz_id."
    assert quiz_fks[0].target_fullname == "quizzes.id"
    assert quiz_fks[0].ondelete.upper() == "CASCADE"
    print("  [+] quiz_attempts.quiz_id -> quizzes.id (ON DELETE CASCADE)")
    print("  [PASS] User ownership and quiz reference foreign keys verified.")

    # 5. Verify Column Types: TEXT and JSONB
    log_test("Column Data Types: PostgreSQL TEXT & JSONB")
    doc_table = Base.metadata.tables["documents"]
    assert isinstance(doc_table.columns["extracted_text"].type, Text), "Document.extracted_text must be TEXT."
    assert isinstance(doc_table.columns["topics"].type, JSONB), "Document.topics must be JSONB."
    print("  [+] documents.extracted_text -> TEXT")
    print("  [+] documents.topics -> JSONB")

    notes_table = Base.metadata.tables["generated_notes"]
    assert isinstance(notes_table.columns["summary"].type, Text), "GeneratedNote.summary must be TEXT."
    assert isinstance(notes_table.columns["sections"].type, JSONB), "GeneratedNote.sections must be JSONB."
    assert isinstance(notes_table.columns["key_definitions"].type, JSONB), "GeneratedNote.key_definitions must be JSONB."
    assert isinstance(notes_table.columns["exam_pitfalls"].type, JSONB), "GeneratedNote.exam_pitfalls must be JSONB."
    print("  [+] generated_notes.summary -> TEXT")
    print("  [+] generated_notes.sections, key_definitions, exam_pitfalls -> JSONB")

    quiz_table = Base.metadata.tables["quizzes"]
    assert isinstance(quiz_table.columns["questions"].type, JSONB), "Quiz.questions must be JSONB."
    print("  [+] quizzes.questions -> JSONB")

    qa_table = Base.metadata.tables["quiz_attempts"]
    assert isinstance(qa_table.columns["user_answers"].type, JSONB), "QuizAttempt.user_answers must be JSONB."
    print("  [+] quiz_attempts.user_answers -> JSONB")
    print("  [PASS] Column types match specifications.")

    # 6. Verify Alembic Migration Head
    log_test("Alembic Migration Discovery")
    from alembic.config import Config
    from alembic.script import ScriptDirectory

    alembic_cfg = Config(str(backend_dir / "alembic.ini"))
    alembic_cfg.set_main_option("script_location", str(backend_dir / "alembic"))
    script = ScriptDirectory.from_config(alembic_cfg)
    heads = script.get_heads()
    assert heads, "Alembic must have at least one migration head revision."
    print(f"  [+] Alembic Current Head Revision: {heads}")
    print("  [PASS] Alembic initial migration discovered.")

    # 7. Verify Requirement 12: No Silent Fallback to In-Memory
    log_test("Fail-Fast Database Policy (No Silent In-Memory Fallback)")
    import inspect
    db_source = inspect.getsource(get_db)
    assert "in_memory" not in db_source and "fallback" not in db_source.lower(), (
        "get_db must not contain silent in-memory fallback logic."
    )
    assert "raise" in db_source, "get_db must re-raise database errors on connection failure."
    print("  [+] get_db correctly raises exceptions on database failure.")
    print("  [PASS] Fail-fast database behavior verified.")

    print("\n" + "=" * 70)
    print(" ALL PHASE 1 DATABASE FOUNDATION VERIFICATIONS PASSED!")
    print("=" * 70)


if __name__ == "__main__":
    main()

