"""Publish only generated review images or a dependency lockfile in CI logs."""
import base64
import hashlib
import sys
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
kind = sys.argv[1]
paths = list((root / 'apps/mobile/build/screenshots').glob('*.png')) if kind == 'mobile' else [root / 'apps/admin/package-lock.json']
archive = root / 'ci-review.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as output:
    for path in paths:
        if path.is_file():
            output.write(path, path.relative_to(root))
raw = archive.read_bytes()
print('EATME_REVIEW_SHA256:' + hashlib.sha256(raw).hexdigest())
encoded = base64.b64encode(raw).decode()
for offset in range(0, len(encoded), 3000):
    print('EATME_REVIEW_CHUNK:' + encoded[offset:offset+3000])
