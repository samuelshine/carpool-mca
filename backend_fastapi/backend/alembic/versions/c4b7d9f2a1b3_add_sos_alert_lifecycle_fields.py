"""Add SOS alert lifecycle fields

Revision ID: c4b7d9f2a1b3
Revises: ad9dba31b12a
Create Date: 2026-03-19 19:45:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "c4b7d9f2a1b3"
down_revision: Union[str, Sequence[str], None] = "ad9dba31b12a"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    sos_status_enum = sa.Enum(
        "open",
        "resolved",
        "closed",
        name="sosalertstatusenum",
    )
    sos_status_enum.create(op.get_bind(), checkfirst=True)

    op.add_column(
        "sos_alerts",
        sa.Column(
            "status",
            sos_status_enum,
            nullable=True,
            server_default="open",
        ),
    )
    op.add_column(
        "sos_alerts",
        sa.Column("resolved_at", sa.TIMESTAMP(timezone=True), nullable=True),
    )
    op.add_column(
        "sos_alerts",
        sa.Column("resolved_by_user_id", sa.UUID(), nullable=True),
    )
    op.add_column(
        "sos_alerts",
        sa.Column("resolution_notes", sa.Text(), nullable=True),
    )

    op.execute("UPDATE sos_alerts SET status = 'open' WHERE status IS NULL")
    op.alter_column(
        "sos_alerts",
        "status",
        nullable=False,
        server_default="open",
        existing_type=sos_status_enum,
    )
    op.create_foreign_key(
        "fk_sos_alerts_resolved_by_user_id_users",
        "sos_alerts",
        "users",
        ["resolved_by_user_id"],
        ["user_id"],
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_constraint(
        "fk_sos_alerts_resolved_by_user_id_users",
        "sos_alerts",
        type_="foreignkey",
    )
    op.drop_column("sos_alerts", "resolution_notes")
    op.drop_column("sos_alerts", "resolved_by_user_id")
    op.drop_column("sos_alerts", "resolved_at")
    op.drop_column("sos_alerts", "status")

    sos_status_enum = sa.Enum(
        "open",
        "resolved",
        "closed",
        name="sosalertstatusenum",
    )
    sos_status_enum.drop(op.get_bind(), checkfirst=True)
