from io import BytesIO

from PIL import Image

from ..errors import AppError

MAX_IMAGE_BYTES = 8 * 1024 * 1024
ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/webp", "image/heic", "image/heif"}


def validate_image(image_bytes: bytes, mime_type: str) -> None:
    if mime_type not in ALLOWED_MIME_TYPES:
        raise AppError(
            "INVALID_IMAGE_TYPE",
            "Only JPEG, PNG, WEBP, HEIC, or HEIF images are supported.",
            status_code=422,
        )
    if len(image_bytes) > MAX_IMAGE_BYTES:
        raise AppError(
            "IMAGE_TOO_LARGE",
            "Image must be 8MB or smaller.",
            status_code=413,
        )
    try:
        with Image.open(BytesIO(image_bytes)) as image:
            image.verify()
    except Exception as exc:
        raise AppError(
            "INVALID_IMAGE",
            "Uploaded file is not a valid image.",
            status_code=422,
        ) from exc
