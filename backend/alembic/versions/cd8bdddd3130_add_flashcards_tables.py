"""add_flashcards_tables

Revision ID: cd8bdddd3130
Revises: f2f6ab18a4a2
Create Date: 2026-10-29 01:45:44.978391

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = 'cd8bdddd3130'
down_revision: Union[str, Sequence[str], None] = 'f2f6ab18a4a2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Flashcard Decks Table
    op.create_table(
        'flashcard_decks',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('document_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('documents.id', ondelete='SET NULL'), nullable=True),
        sa.Column('note_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('generated_notes.id', ondelete='SET NULL'), nullable=True),
        sa.Column('title', sa.String(length=255), nullable=False),
        sa.Column('subject', sa.String(length=100), server_default='General', nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('card_count', sa.Integer(), server_default='0', nullable=False),
        sa.Column('mastered_count', sa.Integer(), server_default='0', nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index(op.f('ix_flashcard_decks_id'), 'flashcard_decks', ['id'], unique=False)
    op.create_index(op.f('ix_flashcard_decks_user_id'), 'flashcard_decks', ['user_id'], unique=False)
    op.create_index(op.f('ix_flashcard_decks_document_id'), 'flashcard_decks', ['document_id'], unique=False)
    op.create_index(op.f('ix_flashcard_decks_note_id'), 'flashcard_decks', ['note_id'], unique=False)
    op.create_index(op.f('ix_flashcard_decks_subject'), 'flashcard_decks', ['subject'], unique=False)

    # 2. Flashcards Table
    op.create_table(
        'flashcards',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('deck_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('flashcard_decks.id', ondelete='CASCADE'), nullable=False),
        sa.Column('front', sa.Text(), nullable=False),
        sa.Column('back', sa.Text(), nullable=False),
        sa.Column('hint', sa.Text(), nullable=True),
        sa.Column('order_index', sa.Integer(), server_default='0', nullable=False),
        sa.Column('status', sa.String(length=20), server_default='unreviewed', nullable=False),
        sa.Column('review_count', sa.Integer(), server_default='0', nullable=False),
        sa.Column('last_reviewed_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index(op.f('ix_flashcards_id'), 'flashcards', ['id'], unique=False)
    op.create_index(op.f('ix_flashcards_deck_id'), 'flashcards', ['deck_id'], unique=False)
    op.create_index(op.f('ix_flashcards_status'), 'flashcards', ['status'], unique=False)

    # 3. Flashcard Reviews Table
    op.create_table(
        'flashcard_reviews',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('deck_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('flashcard_decks.id', ondelete='CASCADE'), nullable=False),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('cards_reviewed', sa.Integer(), server_default='0', nullable=False),
        sa.Column('known_count', sa.Integer(), server_default='0', nullable=False),
        sa.Column('review_again_count', sa.Integer(), server_default='0', nullable=False),
        sa.Column('duration_seconds', sa.Integer(), server_default='0', nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index(op.f('ix_flashcard_reviews_id'), 'flashcard_reviews', ['id'], unique=False)
    op.create_index(op.f('ix_flashcard_reviews_deck_id'), 'flashcard_reviews', ['deck_id'], unique=False)
    op.create_index(op.f('ix_flashcard_reviews_user_id'), 'flashcard_reviews', ['user_id'], unique=False)


def downgrade() -> None:
    op.drop_table('flashcard_reviews')
    op.drop_table('flashcards')
    op.drop_table('flashcard_decks')
