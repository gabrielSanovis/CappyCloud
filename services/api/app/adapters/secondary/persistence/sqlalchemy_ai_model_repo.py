from __future__ import annotations

import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.entities import AiModel as AiModelEntity
from app.infrastructure.orm_models import AiModel as AiModelORM
from app.ports.repositories import AiModelRepository


class SqlAlchemyAiModelRepository(AiModelRepository):
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get(self, model_id: uuid.UUID) -> AiModelEntity | None:
        orm = await self._session.get(AiModelORM, model_id)
        if not orm:
            return None
        return self._to_entity(orm)

    async def list_active(self) -> list[AiModelEntity]:
        stmt = select(AiModelORM).where(AiModelORM.active == True).order_by(AiModelORM.display_name)
        result = await self._session.execute(stmt)
        return [self._to_entity(orm) for orm in result.scalars()]

    def _to_entity(self, orm: AiModelORM) -> AiModelEntity:
        return AiModelEntity(
            id=orm.id,
            provider_id=orm.provider_id,
            model_id=orm.model_id,
            display_name=orm.display_name,
            capabilities=orm.capabilities,
            is_default=orm.is_default,
            context_window=orm.context_window,
            active=orm.active,
            created_at=orm.created_at,
        )
