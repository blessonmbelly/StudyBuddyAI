"""add_note_evaluations_table

Revision ID: b2c3d4e5f6a7
Revises: a1b2c3d4e5f6
Create Date: 2026-11-04 21:55:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = 'b2c3d4e5f6a7'
down_revision: Union[str, Sequence[str], None] = 'a1b2c3d4e5f6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'note_evaluations',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('document_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('documents.id', ondelete='CASCADE'), nullable=False),
        sa.Column('topic_relevance_score', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('factual_accuracy_score', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('content_completeness_score', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('overall_score', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('quality_grade', sa.String(length=20), nullable=False, server_default='N/A'),
        sa.Column('summary', sa.Text(), nullable=False, server_default=''),
        sa.Column('flagged_claims', postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default='[]'),
        sa.Column('missing_topics', postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default='[]'),
        sa.Column('verified_facts', postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default='[]'),
        sa.Column('uncertain_claims', postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default='[]'),
        sa.Column('additional_context', postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default='[]'),
        sa.Column('strengths', postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default='[]'),
        sa.Column('weaknesses', postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default='[]'),
        sa.Column('recommendations', postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default='[]'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index(op.f('ix_note_evaluations_id'), 'note_evaluations', ['id'], unique=False)
    op.create_index(op.f('ix_note_evaluations_user_id'), 'note_evaluations', ['user_id'], unique=False)
    op.create_index(op.f('ix_note_evaluations_document_id'), 'note_evaluations', ['document_id'], unique=True)


def downgrade() -> None:
    op.drop_index(op.f('ix_note_evaluations_document_id'), table_name='note_evaluations')
    op.drop_index(op.f('ix_note_evaluations_user_id'), table_name='note_evaluations')
    op.drop_index(op.f('ix_note_evaluations_id'), table_name='note_evaluations')
    op.drop_table('note_evaluations')

