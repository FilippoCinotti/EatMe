"""Upload targets for production assets.

``SupabaseStorage`` writes to the public catalog bucket (the same
``eatme-catalog-media`` bucket and settings the catalog already uses) with the
service-role key from the environment. ``LocalStorage`` writes into a folder,
for previews on the GPU machine and for tests.
"""
from __future__ import annotations

import json
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

DEFAULT_BUCKET = 'eatme-catalog-media'
BUCKET_SETTINGS = {'public': True, 'file_size_limit': 2_000_000, 'allowed_mime_types': ['image/webp']}
CACHE_SECONDS = 31_536_000  # paths are immutable per generation


class StorageError(RuntimeError):
    pass


def _call(url, *, data=None, headers=None, method=None, timeout=120):
    request = Request(url, data=data, headers=headers or {}, method=method)
    try:
        with urlopen(request, timeout=timeout) as response:
            return response.status, response.read()
    except HTTPError as error:
        return error.code, error.read()


class SupabaseStorage:
    def __init__(self, base_url, service_key, bucket=DEFAULT_BUCKET, call=_call):
        if not base_url.startswith('https://'):
            raise StorageError('SUPABASE_URL must start with https://')
        self.base = base_url.rstrip('/')
        self.bucket = bucket
        self._key = service_key
        self._call = call

    def _headers(self, **extra):
        return {'Authorization': 'Bearer ' + self._key, 'apikey': self._key, **extra}

    def ensure_bucket(self):
        status, _ = self._call(f'{self.base}/storage/v1/bucket/{self.bucket}', headers=self._headers())
        if status == 404:
            body = json.dumps({'id': self.bucket, 'name': self.bucket, **BUCKET_SETTINGS}).encode()
            status, payload = self._call(f'{self.base}/storage/v1/bucket', data=body, method='POST',
                                         headers=self._headers(**{'Content-Type': 'application/json'}))
            if not 200 <= status < 300:
                raise StorageError(f'bucket creation failed with HTTP {status}: {payload[:200]!r}')
        elif not 200 <= status < 300:
            raise StorageError(f'bucket lookup failed with HTTP {status}')

    def public_url(self, path):
        return f'{self.base}/storage/v1/object/public/{self.bucket}/{path}'

    def upload(self, path, data, content_type='image/webp'):
        # x-upsert only matters when a crashed attempt of the same generation left a file behind;
        # a new generation always gets a new path, so an approved image is never overwritten.
        status, payload = self._call(
            f'{self.base}/storage/v1/object/{self.bucket}/{path}', data=data, method='POST',
            headers=self._headers(**{'Content-Type': content_type, 'x-upsert': 'true',
                                     'Cache-Control': f'max-age={CACHE_SECONDS}'}))
        if not 200 <= status < 300:
            raise StorageError(f'upload of {path} failed with HTTP {status}: {payload[:200]!r}')
        return self.public_url(path)


class LocalStorage:
    def __init__(self, directory, base_url=None):
        self.directory = Path(directory)
        self.base_url = base_url

    def ensure_bucket(self):
        self.directory.mkdir(parents=True, exist_ok=True)

    def public_url(self, path):
        return f'{self.base_url.rstrip("/")}/{path}' if self.base_url else (self.directory / path).resolve().as_uri()

    def upload(self, path, data, content_type='image/webp'):
        target = self.directory / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        return self.public_url(path)
