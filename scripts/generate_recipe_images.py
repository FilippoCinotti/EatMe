"""Generate EatMe-owned AI photos for catalog recipes and attach them in the database.

For every recipe in the verified catalog whose database row has no image_url yet:
  1. generate a photo from its image_prompt with the OpenAI Images API,
  2. upload it to a public Supabase Storage bucket (recipes/<slug>.webp),
  3. set image_url (and image_source metadata) on the recipe row.

The run is resumable: rows that already carry an image_url are skipped, so it
can be re-run after a failure or in several smaller batches (--limit).

Environment:
  OPENAI_API_KEY             OpenAI key with image generation access
  SUPABASE_URL               https://<project>.supabase.co
  SUPABASE_SERVICE_ROLE_KEY  service-role key (Storage upload); never printed
  CATALOG_DATABASE_URL       PostgreSQL URL with write access to recipes
  CATALOG_MEDIA_BUCKET       optional, default eatme-catalog-media (public)
"""
import argparse
import base64
import json
import os
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'generated' / 'verified_recipes_catalog.json'
STYLE = ('Editorial food photograph for a recipe app, natural daylight, shallow depth of field, '
         'neutral table and props, appetising and realistic, no text, no logos, no people or hands. ')


def call(url, *, data=None, headers=None, method=None, timeout=180):
    request = Request(url, data=data, headers=headers or {}, method=method)
    try:
        with urlopen(request, timeout=timeout) as response:
            return response.status, response.read()
    except HTTPError as error:
        return error.code, error.read()


def ensure_bucket(base, key, bucket):
    headers = {'Authorization': 'Bearer ' + key, 'apikey': key, 'Content-Type': 'application/json'}
    status, _ = call(f'{base}/storage/v1/bucket/{bucket}', headers=headers)
    if status == 404:
        body = json.dumps({'id': bucket, 'name': bucket, 'public': True, 'file_size_limit': 2_000_000,
                           'allowed_mime_types': ['image/webp']}).encode()
        status, payload = call(f'{base}/storage/v1/bucket', data=body, headers=headers, method='POST')
        if not 200 <= status < 300:
            raise SystemExit(f'Bucket creation failed with HTTP {status}: {payload[:200]!r}')
    elif not 200 <= status < 300:
        raise SystemExit(f'Bucket lookup failed with HTTP {status}.')


def generate(prompt, model, quality, api_key):
    body = json.dumps({'model': model, 'prompt': STYLE + prompt, 'size': '1024x1024', 'quality': quality,
                       'output_format': 'webp', 'output_compression': 80, 'n': 1}).encode()
    headers = {'Authorization': 'Bearer ' + api_key, 'Content-Type': 'application/json'}
    for attempt in range(5):
        status, payload = call('https://api.openai.com/v1/images/generations', data=body, headers=headers,
                               method='POST', timeout=300)
        if status == 200:
            return base64.b64decode(json.loads(payload)['data'][0]['b64_json'])
        if status in (429, 500, 502, 503, 504):
            time.sleep(10 * (attempt + 1))
            continue
        raise RuntimeError(f'OpenAI HTTP {status}: {payload[:300]!r}')
    raise RuntimeError('OpenAI kept failing after retries')


def upload(base, key, bucket, path, image):
    headers = {'Authorization': 'Bearer ' + key, 'apikey': key, 'Content-Type': 'image/webp',
               'x-upsert': 'true', 'Cache-Control': '31536000'}
    status, payload = call(f'{base}/storage/v1/object/{bucket}/{path}', data=image, headers=headers, method='POST')
    if not 200 <= status < 300:
        raise RuntimeError(f'Upload HTTP {status}: {payload[:200]!r}')
    return f'{base}/storage/v1/object/public/{bucket}/{path}'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--limit', type=int, default=0, help='max images this run (0 = all missing)')
    parser.add_argument('--model', default=os.environ.get('IMAGE_MODEL') or 'gpt-image-1')
    parser.add_argument('--quality', default='medium', choices=['low', 'medium', 'high'])
    parser.add_argument('--workers', type=int, default=4)
    parser.add_argument('--dry-run', action='store_true', help='list what would be generated')
    args = parser.parse_args()

    base = os.environ.get('SUPABASE_URL', '').rstrip('/')
    storage_key = os.environ.get('SUPABASE_SERVICE_ROLE_KEY', '')
    api_key = os.environ.get('OPENAI_API_KEY', '')
    database = os.environ.get('CATALOG_DATABASE_URL', '')
    bucket = os.environ.get('CATALOG_MEDIA_BUCKET') or 'eatme-catalog-media'
    if not database or (not args.dry_run and not (base.startswith('https://') and storage_key and api_key)):
        sys.exit('Set CATALOG_DATABASE_URL, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY and OPENAI_API_KEY.')

    import psycopg

    catalog = json.loads(CATALOG.read_text())
    with psycopg.connect(database) as connection:
        rows = {row[0]: json.loads(row[1]) for row in connection.execute(
            'SELECT id, data FROM recipes WHERE id = ANY(%s)', ([r['id'] for r in catalog['recipes']],))}
        todo = [r for r in catalog['recipes'] if r['id'] in rows and not rows[r['id']].get('image_url')
                and r.get('image_prompt')]
        missing = sum(r['id'] not in rows for r in catalog['recipes'])
        if args.limit:
            todo = todo[:args.limit]
        print(f'{len(todo)} images to generate; {missing} catalog recipes not loaded yet (run the loader first).')
        if args.dry_run or not todo:
            return
        ensure_bucket(base, storage_key, bucket)

        def work(recipe):
            image = generate(recipe['image_prompt'], args.model, args.quality, api_key)
            return recipe, upload(base, storage_key, bucket, f"recipes/{recipe['slug']}.webp", image)

        done = failed = 0
        with ThreadPoolExecutor(max_workers=args.workers) as pool:
            futures = [pool.submit(work, recipe) for recipe in todo]
            for future in as_completed(futures):
                try:
                    recipe, url = future.result()
                except (RuntimeError, URLError, TimeoutError, OSError) as error:
                    failed += 1
                    print('FAILED', str(error)[:200], flush=True)
                    continue
                data = rows[recipe['id']] | {'image_url': url, 'image_source': {
                    'kind': 'ai-generated', 'model': args.model, 'owner': 'EatMe'}}
                with connection.transaction():
                    connection.execute('UPDATE recipes SET data = %s WHERE id = %s', (
                        json.dumps(data, sort_keys=True, ensure_ascii=False, separators=(',', ':')), recipe['id']))
                done += 1
                if done % 25 == 0:
                    print(f'{done}/{len(todo)} images attached', flush=True)
        print(f'Attached {done} images; {failed} failed (re-run to retry).')
        if failed:
            sys.exit(1)


if __name__ == '__main__':
    main()
