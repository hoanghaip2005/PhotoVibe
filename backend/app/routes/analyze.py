import json
from typing import Annotated

from fastapi import APIRouter, Depends, File, Form, UploadFile

from ..deps import analysis_service_dep
from ..errors import AppError
from ..models import AnalysisMode, VibeResult
from ..services.analysis_service import AnalysisService
from ..utils.image_validation import validate_image

router = APIRouter(tags=["analysis"])


@router.post("/analyze", response_model=VibeResult)
async def analyze_image(
    service: Annotated[AnalysisService, Depends(analysis_service_dep)],
    image: UploadFile = File(...),
    hint: str = Form(default=""),
    moodHints: list[str] = Form(default=[]),
    moodHintsJson: str | None = Form(default=None),
    analysisMode: AnalysisMode = Form(default=AnalysisMode.auto),
    userId: str | None = Form(default=None),
    anonymousId: str | None = Form(default=None),
    saveResult: bool = Form(default=False),
    userProfileJson: str | None = Form(default=None),
) -> VibeResult:
    # Runtime endpoint intentionally never calls Spotify. Music comes from Supabase pgvector.
    if image.content_type is None:
        raise AppError("INVALID_IMAGE_TYPE", "Missing image content type.", status_code=422)
    image_bytes = await image.read()
    validate_image(image_bytes, image.content_type)
    parsed_mood_hints = moodHints
    if moodHintsJson:
        parsed_mood_hints = [str(item) for item in json.loads(moodHintsJson)]
    return await service.analyze(
        image_bytes=image_bytes,
        mime_type=image.content_type,
        hint=hint,
        mood_hints=parsed_mood_hints,
        analysis_mode=analysisMode,
        user_id=userId,
        anonymous_id=anonymousId,
        save_result=saveResult,
        inline_preferences_json=userProfileJson,
    )
