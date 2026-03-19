"""Add driver live location fields to rides

Revision ID: 7d2f6c5b8e10
Revises: c4b7d9f2a1b3
Create Date: 2026-03-19 23:10:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "7d2f6c5b8e10"
down_revision: Union[str, Sequence[str], None] = "c4b7d9f2a1b3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        "rides",
        sa.Column("driver_last_latitude", sa.Float(), nullable=True),
    )
    op.add_column(
        "rides",
        sa.Column("driver_last_longitude", sa.Float(), nullable=True),
    )
    op.add_column(
        "rides",
        sa.Column("driver_location_updated_at", sa.TIMESTAMP(timezone=True), nullable=True),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("rides", "driver_location_updated_at")
    op.drop_column("rides", "driver_last_longitude")
    op.drop_column("rides", "driver_last_latitude")
