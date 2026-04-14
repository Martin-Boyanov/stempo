"""create song_cache table

Revision ID: 20260414_0001
Revises:
Create Date: 2026-04-14 00:00:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "20260414_0001"
down_revision: Union[str, Sequence[str], None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "song_cache",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("song_uuid", sa.String(length=64), nullable=True),
        sa.Column("isrc", sa.String(length=32), nullable=True),
        sa.Column("spotify_id", sa.String(length=128), nullable=True),
        sa.Column("resolved_by", sa.String(length=32), nullable=False),
        sa.Column("payload", sa.JSON(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_song_cache_song_uuid", "song_cache", ["song_uuid"], unique=False)
    op.create_index("ix_song_cache_isrc", "song_cache", ["isrc"], unique=False)
    op.create_index("ix_song_cache_spotify_id", "song_cache", ["spotify_id"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_song_cache_spotify_id", table_name="song_cache")
    op.drop_index("ix_song_cache_isrc", table_name="song_cache")
    op.drop_index("ix_song_cache_song_uuid", table_name="song_cache")
    op.drop_table("song_cache")
