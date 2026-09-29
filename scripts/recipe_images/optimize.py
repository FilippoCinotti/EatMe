"""Turn a generated source image into the validated production WebP asset.

The app shows recipe images with ``BoxFit.cover`` in 1.6:1 heroes (full width,
up to 320 px tall) and in small square thumbnails, so the source is generated
at 1.6:1 with the dish centred and the asset is 1200x750: sharp on 3x phone
screens without shipping multi-megabyte files.
"""
from __future__ import annotations

import hashlib
import io
from dataclasses import dataclass

from PIL import Image, ImageStat

SOURCE_SIZE = (1280, 800)      # multiple of 16, as FLUX requires
ASSET_SIZE = (1200, 750)
ASSET_FORMAT = 'WEBP'
QUALITY_STEPS = (82, 76, 70, 64)
MAX_BYTES = 450_000            # bucket limit is 2 MB; keep catalog downloads light
MIN_BYTES = 12_000             # a near-empty image compresses below this
MIN_DETAIL = 12.0              # mean channel standard deviation; flat/blank frames fall below


class InvalidImage(ValueError):
    pass


@dataclass
class Asset:
    data: bytes
    width: int
    height: int
    source_width: int
    source_height: int
    quality: int
    sha256: str

    @property
    def bytes(self):
        return len(self.data)


def _cover(image, size):
    """Scale and centre-crop ``image`` to exactly ``size``."""
    target_w, target_h = size
    scale = max(target_w / image.width, target_h / image.height)
    resized = image.resize((max(target_w, round(image.width * scale)), max(target_h, round(image.height * scale))),
                           Image.Resampling.LANCZOS)
    left = (resized.width - target_w) // 2
    top = (resized.height - target_h) // 2
    return resized.crop((left, top, left + target_w, top + target_h))


def optimize(image, size=ASSET_SIZE, max_bytes=MAX_BYTES):
    if not isinstance(image, Image.Image):
        raise InvalidImage('provider did not return an image')
    source_w, source_h = image.size
    if source_w < size[0] or source_h < size[1]:
        raise InvalidImage(f'source {source_w}x{source_h} is smaller than {size[0]}x{size[1]}')
    frame = _cover(image.convert('RGB'), size)
    for quality in QUALITY_STEPS:
        buffer = io.BytesIO()
        frame.save(buffer, ASSET_FORMAT, quality=quality, method=6)
        data = buffer.getvalue()
        if len(data) <= max_bytes:
            break
    return Asset(data=data, width=size[0], height=size[1], source_width=source_w, source_height=source_h,
                 quality=quality, sha256=hashlib.sha256(data).hexdigest())


def validate(asset, size=ASSET_SIZE, max_bytes=MAX_BYTES, min_bytes=MIN_BYTES):
    """Reject files that are not a plausible production image before upload."""
    if not asset.data:
        raise InvalidImage('empty file')
    if len(asset.data) > max_bytes:
        raise InvalidImage(f'{len(asset.data)} bytes exceeds the {max_bytes} byte limit')
    if len(asset.data) < min_bytes:
        raise InvalidImage(f'{len(asset.data)} bytes is too small for a photograph')
    try:
        with Image.open(io.BytesIO(asset.data)) as probe:
            probe.verify()
        with Image.open(io.BytesIO(asset.data)) as image:
            if image.format != ASSET_FORMAT:
                raise InvalidImage(f'format {image.format} is not {ASSET_FORMAT}')
            if image.size != tuple(size):
                raise InvalidImage(f'size {image.size} is not {tuple(size)}')
            detail = sum(ImageStat.Stat(image.convert('RGB')).stddev) / 3
    except InvalidImage:
        raise
    except Exception as error:  # Pillow raises several unrelated types for corrupt data
        raise InvalidImage(f'unreadable image: {error}') from error
    if detail < MIN_DETAIL:
        raise InvalidImage(f'image is nearly uniform (detail {detail:.1f})')
    return asset
