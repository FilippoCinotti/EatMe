"""Generate original hero photos for EatMe catalog recipes with a local open model.

No paid image API is used: the default provider runs FLUX.1-schnell locally
through Diffusers on a GPU machine. Images are reviewed before the app shows
them: generation stores a candidate, and only --approve sets image_url.
Full guide: docs/catalog/recipe-images.md

Common commands:
  python scripts/generate_recipe_images.py --dry-run --limit 5          # prompts only, no GPU, no writes
  python scripts/generate_recipe_images.py --missing --sample 10        # 10 representative recipes
  python scripts/generate_recipe_images.py --missing --limit 200        # resumable batch
  python scripts/generate_recipe_images.py --recipe authentic-carbonara --regenerate
  python scripts/generate_recipe_images.py --review-sheet review.html   # candidates awaiting review
  python scripts/generate_recipe_images.py --approve authentic-carbonara
  python scripts/generate_recipe_images.py --reject authentic-carbonara --reason "cream visible"
  python scripts/generate_recipe_images.py --preview build/recipe-images --sample 10   # local files only

Environment (never printed, never committed):
  CATALOG_DATABASE_URL       PostgreSQL URL with write access to recipes (omit for --dry-run from the catalog file)
  SUPABASE_URL               https://<project>.supabase.co
  SUPABASE_SERVICE_ROLE_KEY  service-role key used only for the Storage upload
  CATALOG_MEDIA_BUCKET       optional, default eatme-catalog-media (public, image/webp)
  HF_TOKEN                   Hugging Face token whose account accepted the FLUX.1-schnell terms
  RECIPE_IMAGE_MODEL         optional model id or local path, default black-forest-labs/FLUX.1-schnell
"""
import argparse
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))

from recipe_images import lifecycle, pipeline  # noqa: E402
from recipe_images.providers import PROVIDERS, ProviderUnavailable, make_provider  # noqa: E402
from recipe_images.storage import DEFAULT_BUCKET, LocalStorage, SupabaseStorage  # noqa: E402
from recipe_images.stores import CatalogFileStore, MemoryStore, PostgresStore  # noqa: E402

EXIT_FAILURES, EXIT_USAGE, EXIT_PROVIDER = 1, 2, 3


def parse(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    what = parser.add_argument_group('what to generate')
    what.add_argument('--missing', action='store_true',
                      help='recipes without an image, queued, rejected, or failed fewer than 3 times (default)')
    what.add_argument('--recipe', action='append', default=[], metavar='ID_OR_SLUG', help='only these recipes')
    what.add_argument('--limit', type=int, default=0, help='max recipes this run (0 = no limit)')
    what.add_argument('--sample', type=int, default=0, help='pick N representative recipes')
    what.add_argument('--regenerate', action='store_true',
                      help='with --recipe: make a new candidate even if an image exists (the approved one stays '
                           'live until the new one is approved)')
    what.add_argument('--retry-failed', action='store_true', help='also retry recipes that failed 3 times')
    mode = parser.add_argument_group('mode')
    mode.add_argument('--dry-run', action='store_true', help='print selection and prompts; no model, no writes')
    mode.add_argument('--preview', type=Path, metavar='DIR',
                      help='generate into DIR only: no upload, no database writes')
    mode.add_argument('--output-dir', type=Path, help='also keep source PNG and WebP asset in this folder')
    mode.add_argument('--status', action='store_true', help='print image status counts')
    mode.add_argument('--review-sheet', type=Path, metavar='HTML', help='write a page with candidates to review')
    review = parser.add_argument_group('review')
    review.add_argument('--approve', nargs='+', metavar='ID_OR_SLUG', help='serve these candidates in the app')
    review.add_argument('--reject', nargs='+', metavar='ID_OR_SLUG', help='reject; the next batch regenerates them')
    review.add_argument('--queue', nargs='+', metavar='ID_OR_SLUG', help='queue for regeneration by the next batch')
    review.add_argument('--reason', default='', help='rejection reason kept in the metadata')
    review.add_argument('--reviewer', default=None, help='name stored with an approval')
    model = parser.add_argument_group('model')
    model.add_argument('--provider', default='flux-schnell', choices=sorted(PROVIDERS))
    model.add_argument('--model', default=None, help='model id or local path (default FLUX.1-schnell)')
    model.add_argument('--offload', default='model', choices=['none', 'model', 'sequential'],
                       help='CUDA memory strategy: none (~33 GB), model (~16-24 GB), sequential (<12 GB, slow)')
    model.add_argument('--allow-cpu', action='store_true', help='allow CPU inference (smoke tests only)')
    parser.add_argument('--source', choices=['auto', 'db', 'catalog'], default='auto',
                        help='read recipes from the database or the committed catalog file (dry run/preview)')
    return parser.parse_args(argv)


def open_store(args, need_writes):
    url = os.environ.get('CATALOG_DATABASE_URL')
    source = args.source if args.source != 'auto' else ('db' if url else 'catalog')
    if source == 'db':
        if not url:
            raise SystemExit('CATALOG_DATABASE_URL is not set.')
        return PostgresStore(url)
    if need_writes:
        raise SystemExit('Writing image state needs the database: set CATALOG_DATABASE_URL (or use --dry-run/--preview).')
    return CatalogFileStore(ROOT)


def main(argv=None):
    args = parse(argv)
    if args.regenerate and not args.recipe:
        print('--regenerate needs explicit --recipe ids; approved images are never replaced in bulk.', file=sys.stderr)
        return EXIT_USAGE
    curated = lifecycle.curated_recipe_ids(ROOT)
    reviewing = args.approve or args.reject or args.queue
    read_only = args.dry_run or args.preview or args.status or args.review_sheet
    store = open_store(args, need_writes=bool(reviewing) or not read_only)

    if reviewing:
        action, ids = next((a, v) for a, v in (('approve', args.approve), ('reject', args.reject),
                                                ('queue', args.queue)) if v)
        changed = pipeline.review(store, action=action, recipe_ids=ids, reason=args.reason, reviewer=args.reviewer,
                                  curated=curated)
        print(f'{changed} of {len(ids)} recipe(s) {pipeline.PAST[action]}')
        return 0 if changed == len(ids) else EXIT_FAILURES
    if args.status or args.review_sheet:
        recipes = store.recipes()
        if args.status:
            for status, count in pipeline.status_report(recipes, curated).items():
                print(f'{status:>11} {count}')
        if args.review_sheet:
            print(f'{pipeline.review_sheet(recipes, args.review_sheet)} candidate(s) written to {args.review_sheet}')
        return 0

    options = pipeline.Options(recipes=tuple(args.recipe), limit=args.limit, dry_run=args.dry_run,
                               regenerate=args.regenerate, retry_failed=args.retry_failed, sample=args.sample,
                               output_dir=args.output_dir or args.preview)
    if args.preview:
        store = MemoryStore(store.recipes(), store.foods())  # snapshot: nothing is written back
        storage = LocalStorage(args.preview)
    elif args.dry_run:
        storage = None
    else:
        base, key = os.environ.get('SUPABASE_URL', ''), os.environ.get('SUPABASE_SERVICE_ROLE_KEY', '')
        if not base or not key:
            raise SystemExit('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required to upload images.')
        storage = SupabaseStorage(base, key, os.environ.get('CATALOG_MEDIA_BUCKET', DEFAULT_BUCKET))
    provider = make_provider(args.provider, model=args.model, offload=args.offload, allow_cpu=args.allow_cpu)
    try:
        summary = pipeline.run(options, store, storage, provider, curated=curated)
    except ProviderUnavailable as error:
        print(f'Image model unavailable: {error}', file=sys.stderr)
        print('Nothing was claimed or written. No paid API is used as a fallback.', file=sys.stderr)
        return EXIT_PROVIDER
    print(summary.line() if not args.dry_run else f'dry run: {summary.selected} recipe(s) would be processed')
    for slug, error in summary.failures[:20]:
        print(f'  failed {slug}: {error}')
    if args.preview:
        count = pipeline.review_sheet(store.recipes(), args.preview / 'review.html')
        print(f'{count} preview(s): {args.preview / "review.html"}')
    return EXIT_FAILURES if summary.failed else 0


if __name__ == '__main__':
    sys.exit(main())
