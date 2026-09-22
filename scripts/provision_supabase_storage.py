"""Idempotently provision EatMe+'s server-only private media bucket.

Run only from a trusted operator environment. The service-role key is read from
the environment and is never printed or written to a file.
"""
import json
import os
import sys
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


def request(url, key, *, method="GET", body=None):
    payload = json.dumps(body).encode() if body is not None else None
    headers = {"Authorization": "Bearer " + key, "apikey": key}
    if payload is not None:
        headers["Content-Type"] = "application/json"
    try:
        with urlopen(Request(url, data=payload, headers=headers, method=method), timeout=20) as response:
            return response.status, response.read(262145)
    except HTTPError as error:
        return error.code, error.read(262145)
    except URLError as error:
        raise SystemExit("Supabase Storage is unreachable from this operator environment.") from error


def main():
    url = os.getenv("SUPABASE_URL", "").rstrip("/")
    key = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
    bucket = os.getenv("SUPABASE_MEDIA_BUCKET", "eatme-private-media")
    if not url.startswith("https://") or not key or not bucket.replace("-", "").isalnum():
        raise SystemExit("Set SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY and a valid SUPABASE_MEDIA_BUCKET.")
    endpoint = f"{url}/storage/v1/bucket/{bucket}"
    status, payload = request(endpoint, key)
    if status == 404:
        status, payload = request(
            f"{url}/storage/v1/bucket",
            key,
            method="POST",
            body={
                "id": bucket,
                "name": bucket,
                "public": False,
                "file_size_limit": 6500000,
                "allowed_mime_types": ["application/octet-stream"],
            },
        )
    if not 200 <= status < 300:
        print(f"Bucket provisioning failed with HTTP {status}.", file=sys.stderr)
        raise SystemExit(1)
    status, payload = request(endpoint, key)
    if not 200 <= status < 300:
        raise SystemExit(f"Bucket verification failed with HTTP {status}.")
    try:
        value = json.loads(payload)
    except (ValueError, UnicodeError):
        raise SystemExit("Supabase returned an invalid bucket response.") from None
    if value.get("public") is not False:
        raise SystemExit("Refusing to continue: the media bucket is public.")
    print(f"Private Storage bucket {bucket} is ready.")


if __name__ == "__main__":
    main()
