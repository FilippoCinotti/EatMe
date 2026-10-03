"""Image lifecycle kept inside the recipe's existing ``image_source`` object.

``recipes.data`` is a JSON document; the pipeline only ever changes its
``image_url`` and ``image_source`` keys. ``image_source`` (schema 1)::

    {"kind": "ai-generated", "owner": "EatMe", "schema": 1,
     "status": "missing|queued|generating|generated|approved|rejected|failed",
     "generation": 3,            # last generation number used for a path/seed
     "attempts": 1,              # consecutive failed attempts
     "candidate": {...},         # latest generated image, awaiting review
     "approved": {...} | null,   # image currently served through image_url
     "last_error": "...", "updated_at": "..."}

``image_url`` is set only on approval, so the released app never shows an
image that nobody reviewed. A new candidate for an already approved recipe
leaves the approved image in place until the candidate itself is approved.
"""
from __future__ import annotations

import hashlib
import re
from datetime import datetime, timedelta, timezone
from pathlib import Path

SCHEMA = 1
PIPELINE_VERSION = 'recipe-images-1'
STATUSES = ('missing', 'queued', 'generating', 'generated', 'approved', 'rejected', 'failed')
# Statuses the standard batch (--missing) picks up.
BATCH_STATUSES = {'missing', 'queued', 'rejected'}
STALE_AFTER = timedelta(hours=2)
MAX_ATTEMPTS = 3
PATH_TEMPLATE = 'recipe-images/{recipe_id}/hero-{generation:03d}.webp'


class Ineligible(Exception):
    """The recipe changed state and must not be processed now."""


def now_iso(clock=None):
    return (clock() if clock else datetime.now(timezone.utc)).replace(microsecond=0).isoformat()


def _parse(stamp):
    try:
        return datetime.fromisoformat(stamp)
    except (TypeError, ValueError):
        return None


def source_of(data):
    source = data.get('image_source')
    return dict(source) if isinstance(source, dict) else {}


def status_of(data, curated=frozenset()):
    """Effective status; 'legacy' and 'curated' images are never touched."""
    if data.get('id') in curated:
        return 'curated'
    source = source_of(data)
    status = source.get('status')
    if status in STATUSES:
        return status
    if data.get('image_url'):
        return 'legacy'
    return 'missing'


def needs_image(data, *, curated=frozenset(), clock=None, retry_failed=False, max_attempts=MAX_ATTEMPTS):
    """True when the standard batch should generate an image for this recipe."""
    status = status_of(data, curated)
    if status in BATCH_STATUSES:
        return True
    source = source_of(data)
    if status == 'failed':
        return retry_failed or int(source.get('attempts') or 0) < max_attempts
    if status == 'generating':
        started = _parse(source.get('updated_at'))
        current = clock() if clock else datetime.now(timezone.utc)
        return started is None or current - started > STALE_AFTER
    return False


def storage_path(recipe_id, generation):
    if not re.fullmatch(r'[0-9a-f-]{36}', recipe_id or ''):
        raise ValueError(f'unexpected recipe id {recipe_id!r}')
    return PATH_TEMPLATE.format(recipe_id=recipe_id, generation=int(generation))


def seed_for(recipe_id, generation):
    digest = hashlib.sha256(f'{recipe_id}:{int(generation)}'.encode()).digest()
    return int.from_bytes(digest[:4], 'big') & 0x7FFFFFFF


def curated_recipe_ids(root):
    """Recipes shipped with a bundled editorial image in the Flutter app."""
    source = Path(root) / 'apps/mobile/lib/design_system/food_image.dart'
    if not source.exists():
        return frozenset()
    block = re.search(r'recipeAssets\s*=\s*<String,\s*String>\{(.*?)\};', source.read_text(), re.S)
    return frozenset(re.findall(r"'([0-9a-f-]{36})'\s*:", block.group(1))) if block else frozenset()


# Transitions. Each takes the current recipe data and returns the new
# (image_url, image_source) pair; they raise Ineligible when the state moved.

def claim(data, *, clock=None, regenerate=False, curated=frozenset(), retry_failed=False):
    status = status_of(data, curated)
    if status in ('curated', 'legacy') and not regenerate:
        raise Ineligible(status)
    if status == 'curated':
        raise Ineligible('curated images are managed in the app')
    if not regenerate and not needs_image(data, curated=curated, clock=clock, retry_failed=retry_failed):
        raise Ineligible(status)
    if regenerate and status == 'generating' and not needs_image(data, clock=clock):
        raise Ineligible('generation already in progress')
    source = source_of(data)
    if status == 'legacy':
        # Keep a record of the image that was attached before this pipeline.
        source['approved'] = {'url': data['image_url'], 'legacy': True}
    generation = int(source.get('generation') or 0) + 1
    source.update(kind='ai-generated', owner='EatMe', schema=SCHEMA, status='generating', generation=generation,
                  updated_at=now_iso(clock))
    source.setdefault('approved', None)
    return data.get('image_url'), source


def complete(data, candidate, *, clock=None):
    source = source_of(data)
    if source.get('status') != 'generating' or source.get('generation') != candidate['generation']:
        raise Ineligible('generation was superseded')
    source.update(status='generated', candidate=candidate, attempts=0, last_error=None, updated_at=now_iso(clock))
    return data.get('image_url'), source


def fail(data, error, *, generation, clock=None):
    source = source_of(data)
    if source.get('status') != 'generating' or source.get('generation') != generation:
        raise Ineligible('generation was superseded')
    source.update(status='failed', attempts=int(source.get('attempts') or 0) + 1,
                  last_error=str(error)[:500], updated_at=now_iso(clock))
    return data.get('image_url'), source


def approve(data, *, clock=None, reviewer=None):
    source = source_of(data)
    candidate = source.get('candidate')
    if source.get('status') != 'generated' or not candidate:
        raise Ineligible(f"only generated images can be approved (status {source.get('status') or 'missing'})")
    approved = {**candidate, 'approved_at': now_iso(clock)}
    if reviewer:
        approved['approved_by'] = reviewer
    source.update(status='approved', approved=approved, updated_at=now_iso(clock))
    return candidate['url'], source


def reject(data, *, reason='', clock=None):
    source = source_of(data)
    if source.get('status') not in ('generated', 'approved'):
        raise Ineligible(f"nothing to reject (status {source.get('status') or 'missing'})")
    if source.get('status') == 'approved':
        # Rejecting the served image withdraws it from the app.
        source['rejected'] = source.get('approved')
        source['approved'] = None
        image_url = None
    else:
        source['rejected'] = source.get('candidate')
        image_url = data.get('image_url')
    if source.get('rejected'):
        source['rejected'] = {**source['rejected'], 'rejected_at': now_iso(clock), 'reason': reason[:300]}
    source.update(status='rejected', updated_at=now_iso(clock))
    return image_url, source


def queue(data, *, clock=None, curated=frozenset()):
    status = status_of(data, curated)
    if status == 'curated':
        raise Ineligible('curated images are managed in the app')
    if status == 'generating':
        raise Ineligible('generation already in progress')
    source = source_of(data)
    if status == 'legacy':
        source['approved'] = {'url': data['image_url'], 'legacy': True}
    source.update(kind='ai-generated', owner='EatMe', schema=SCHEMA, status='queued', updated_at=now_iso(clock))
    source.setdefault('approved', None)
    source.setdefault('generation', 0)
    return data.get('image_url'), source

