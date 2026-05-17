from datetime import UTC, datetime

from ..config import Settings
from .supabase import SupabaseRepository


class EmbeddingUsageRepository:
    def __init__(self, settings: Settings, supabase: SupabaseRepository) -> None:
        self.settings = settings
        self.supabase = supabase

    async def log_embedding_call(
        self,
        *,
        operation: str,
        context: str,
        model: str,
        input_text_count: int,
        user_id: str | None = None,
        estimated_tokens: int | None = None,
        estimated_cost: float | None = None,
    ) -> None:
        if not self.settings.has_supabase:
            return
        await self.supabase.insert(
            "embedding_usage",
            {
                "user_id": user_id,
                "operation": operation,
                "context": context,
                "model": model,
                "input_text_count": input_text_count,
                "estimated_tokens": estimated_tokens,
                "estimated_cost": estimated_cost,
                "created_at": datetime.now(UTC).isoformat(),
            },
        )
