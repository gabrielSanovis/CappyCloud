"""add_ai_model_id_to_agent_task

Revision ID: 52a8c0a076cc
Revises: 4706bb4e7c11
Create Date: 2026-04-22 13:32:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "52a8c0a076cc"
down_revision: Union[str, Sequence[str], None] = "4706bb4e7c11"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Adicionar coluna ai_model_id à tabela agent_tasks
    op.add_column('agent_tasks', sa.Column('ai_model_id', sa.UUID(), nullable=True))
    op.create_foreign_key(
        'fk_agent_tasks_ai_model_id_ai_models',
        'agent_tasks', 'ai_models',
        ['ai_model_id'], ['id'],
        ondelete='SET NULL'
    )
    op.create_index(op.f('ix_agent_tasks_ai_model_id'), 'agent_tasks', ['ai_model_id'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_agent_tasks_ai_model_id'), table_name='agent_tasks')
    op.drop_constraint('fk_agent_tasks_ai_model_id_ai_models', 'agent_tasks', type_='foreignkey')
    op.drop_column('agent_tasks', 'ai_model_id')
