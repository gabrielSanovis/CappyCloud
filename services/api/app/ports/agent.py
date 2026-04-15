"""Agent port — ABC for the AI agent pipeline.

The Pipeline class (cappycloud_agent) implements this interface via PipelineAdapter.
Test doubles (FakeAgent) also implement it, proving LSP substitutability.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from collections.abc import Generator


class AgentPort(ABC):
    """Outbound port for the AI agent pipeline."""

    @abstractmethod
    def pipe(
        self,
        user_message: str,
        model_id: str,
        messages: list[dict],  # type: ignore[type-arg]
        body: dict,  # type: ignore[type-arg]
    ) -> Generator[str, None, None]:
        """Stream SSE-formatted chunks from the agent.

        Each yielded string is a complete SSE line, e.g.::

            data: {"type": "text", "content": "Hello"}\\n\\n

        Args:
            user_message: The latest user input.
            model_id: Identifier for the model/pipeline variant.
            messages: Full conversation history as role/content dicts.
            body: Request metadata (user_id, conversation_id, etc.).
        """

    @abstractmethod
    async def on_startup(self) -> None:
        """Initialise resources (connections, background tasks)."""

    @abstractmethod
    async def on_shutdown(self) -> None:
        """Release resources gracefully."""
