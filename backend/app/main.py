from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from .config import get_settings
from .errors import AppError, app_error_handler, http_error_handler
from .routes import admin, analyze, resources


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(
        title="VibeLens API",
        version="1.0.0",
        description="Image-only VibeLens backend with admin Spotify ingestion.",
    )
    app.add_exception_handler(AppError, app_error_handler)
    app.add_exception_handler(HTTPException, http_error_handler)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origin_list,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.include_router(analyze.router)
    app.include_router(resources.router)
    app.include_router(admin.router)

    @app.get("/health")
    async def health() -> dict[str, object]:
        return {
            "status": "ok",
            "env": settings.app_env,
            "openaiConfigured": settings.has_openai,
            "pgvectorConfigured": settings.has_pgvector,
            "supabaseConfigured": settings.has_supabase,
            "supabaseRestConfigured": settings.has_supabase_rest,
            "spotifyConfigured": settings.has_spotify,
        }

    return app


app = create_app()
