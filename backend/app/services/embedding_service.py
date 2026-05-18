import logging
from abc import ABC, abstractmethod

import httpx
from openai import APIConnectionError, APIStatusError, AsyncOpenAI, RateLimitError

from ..config import Settings
from ..errors import AppError

logger = logging.getLogger(__name__)


class EmbeddingService(ABC):
    model: str

    @abstractmethod
    async def embed_text(self, text: str) -> list[float]:
        pass


class _BaseEmbeddingService(EmbeddingService):
    def __init__(self, settings: Settings, model: str) -> None:
        self.settings = settings
        self.model = model

    def _validate_dimension(self, vector: list[float]) -> list[float]:
        expected = self.settings.embedding_dimension
        if expected and len(vector) != expected:
            raise AppError(
                "EMBEDDING_DIMENSION_MISMATCH",
                f"Embedding model returned {len(vector)} dimensions; expected {expected}.",
                status_code=500,
            )
        return vector

    def _log_call(self, input_text_count: int) -> None:
        logger.info(
            "embedding_call model=%s input_text_count=%s dimension=%s",
            self.model,
            input_text_count,
            self.settings.embedding_dimension,
        )


class OpenAIEmbeddingService(_BaseEmbeddingService):
    def __init__(self, settings: Settings) -> None:
        super().__init__(settings, settings.embedding_model)
        self._client = AsyncOpenAI(api_key=settings.openai_api_key) if settings.has_openai else None

    def _ensure_configured(self) -> AsyncOpenAI:
        if self._client is None:
            raise AppError(
                "OPENAI_NOT_CONFIGURED",
                "OpenAI API key is missing.",
                status_code=503,
            )
        return self._client

    async def embed_text(self, text: str) -> list[float]:
        client = self._ensure_configured()
        self._log_call(input_text_count=1)
        try:
            response = await client.embeddings.create(
                model=self.model,
                input=text,
                dimensions=self.settings.embedding_dimension,
            )
        except RateLimitError as exc:
            raise AppError(
                "OPENAI_QUOTA_EXCEEDED",
                "OpenAI quota is exhausted or billing is not enabled for this project.",
                status_code=429,
                details=self._openai_error_detail(exc),
            ) from exc
        except APIConnectionError as exc:
            raise AppError(
                "OPENAI_CONNECTION_FAILED",
                "Could not connect to OpenAI embeddings.",
                status_code=502,
                details=str(exc)[:300],
            ) from exc
        except APIStatusError as exc:
            raise AppError(
                "OPENAI_EMBEDDING_FAILED",
                "OpenAI rejected the embedding request.",
                status_code=502,
                details=self._openai_error_detail(exc),
            ) from exc
        if not response.data:
            raise AppError(
                "EMBEDDING_FAILED",
                "OpenAI did not return an embedding.",
                status_code=502,
            )
        return self._validate_dimension(list(response.data[0].embedding))

    @staticmethod
    def _openai_error_detail(exc: APIStatusError) -> str:
        try:
            return exc.response.text[:500]
        except Exception:
            return str(exc)[:500]


class GeminiEmbeddingService(_BaseEmbeddingService):
    def __init__(self, settings: Settings) -> None:
        super().__init__(settings, settings.gemini_embedding_model)

    async def embed_text(self, text: str) -> list[float]:
        if not self.settings.has_gemini:
            raise AppError(
                "GEMINI_NOT_CONFIGURED",
                "GEMINI_API_KEY is missing.",
                status_code=503,
            )
        self._log_call(input_text_count=1)
        model_name = self.model.removeprefix("models/")
        payload: dict[str, object] = {
            "model": f"models/{model_name}",
            "content": {"parts": [{"text": text}]},
        }
        if self.settings.embedding_dimension:
            payload["outputDimensionality"] = self.settings.embedding_dimension
        async with httpx.AsyncClient(timeout=30) as client:
            response = await client.post(
                f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:embedContent",
                params={"key": self.settings.gemini_api_key},
                json=payload,
            )
        if response.status_code >= 400:
            raise AppError(
                "GEMINI_EMBEDDING_FAILED",
                "Gemini rejected the embedding request.",
                status_code=502,
                details=response.text[:500],
            )
        data = response.json()
        values = data.get("embedding", {}).get("values")
        if not isinstance(values, list):
            raise AppError(
                "EMBEDDING_FAILED",
                "Gemini did not return an embedding.",
                status_code=502,
            )
        return self._validate_dimension([float(value) for value in values])


def embedding_service_from_settings(settings: Settings) -> EmbeddingService:
    provider = settings.embedding_provider.lower().strip()
    if provider == "openai":
        return OpenAIEmbeddingService(settings)
    if provider == "gemini":
        return GeminiEmbeddingService(settings)
    raise AppError(
        "EMBEDDING_PROVIDER_NOT_SUPPORTED",
        f"Unsupported embedding provider: {settings.embedding_provider}.",
        status_code=503,
    )
