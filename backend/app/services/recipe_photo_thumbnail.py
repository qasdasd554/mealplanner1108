"""Tworzenie lekkich miniaturek zdjęć przepisów do widoku listy."""

from __future__ import annotations

import base64
import io
import logging

from PIL import Image, ImageOps, UnidentifiedImageError

logger = logging.getLogger(__name__)

_MAX_EDGE = 480
_JPEG_QUALITY = 72


def create_recipe_photo_thumbnail(photo_base64: str | None) -> str | None:
    """Zwraca mały JPEG Base64 albo None, gdy zdjęcia nie da się odczytać.

    Funkcja nie zmienia oryginału. Dzięki temu lista pobiera kilkanaście
    kilobajtów zamiast nawet 3 MB na każdy przepis użytkownika.
    """
    if not photo_base64:
        return None
    try:
        raw = base64.b64decode(photo_base64, validate=True)
        with Image.open(io.BytesIO(raw)) as source:
            source.load()
            image = ImageOps.exif_transpose(source)
            image.thumbnail((_MAX_EDGE, _MAX_EDGE), Image.Resampling.LANCZOS)
            if image.mode in {"RGBA", "LA"}:
                background = Image.new("RGB", image.size, "white")
                alpha = image.getchannel("A")
                background.paste(image.convert("RGB"), mask=alpha)
                image = background
            elif image.mode != "RGB":
                image = image.convert("RGB")
            output = io.BytesIO()
            image.save(
                output,
                format="JPEG",
                quality=_JPEG_QUALITY,
                optimize=True,
                progressive=True,
            )
        return base64.b64encode(output.getvalue()).decode("ascii")
    except (ValueError, OSError, UnidentifiedImageError, Image.DecompressionBombError):
        logger.warning("Nie udało się utworzyć miniatury zdjęcia przepisu")
        return None
