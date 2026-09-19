"""Provider-neutral structured operational events without user payloads."""

import json
import logging
import os
from datetime import datetime, timezone


logger = logging.getLogger("eatme.operations")
logger.setLevel(logging.INFO)


def event(name, *, service, status=None, duration_ms=None, request_id=None, code=None, route=None):
    value = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "event": name,
        "service": service,
        "environment": os.getenv("EATME_ENV", "development"),
        "release_sha": os.getenv("RELEASE_SHA", "unknown"),
    }
    optional = {
        "status": status,
        "duration_ms": duration_ms,
        "request_id": request_id,
        "code": code,
        "route": route,
    }
    value.update({key: item for key, item in optional.items() if item is not None})
    logger.info(json.dumps(value, separators=(",", ":"), sort_keys=True))
