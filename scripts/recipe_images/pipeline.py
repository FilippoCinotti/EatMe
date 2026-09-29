"""Batch orchestration: select, claim, generate, validate, upload, record."""
from __future__ import annotations

import io
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path

from . import lifecycle
from .optimize import ASSET_SIZE, SOURCE_SIZE, InvalidImage, optimize, validate
from .prompt import PROMPT_VERSION, build_prompt, dish_type


@dataclass
class Options:
    recipes: tuple = ()             # explicit recipe ids or slugs
    limit: int = 0
    dry_run: bool = False
    regenerate: bool = False
    retry_failed: bool = False
    sample: int = 0                 # pick N representative recipes instead of the first N
    output_dir: Path | None = None  # keep source PNG and asset locally for review


@dataclass
class Summary:
    selected: int = 0
    processed: int = 0
    generated: int = 0
    uploaded: int = 0
    skipped: int = 0
    failed: int = 0
    failures: list = field(default_factory=list)

    def line(self):
        return (f'processed {self.processed}, generated {self.generated}, uploaded {self.uploaded}, '
                f'skipped {self.skipped}, failed {self.failed}')


def representative_sample(recipes, size):
    """Deterministic spread across dish types, meal slots and cuisines."""
    groups = defaultdict(list)
    for recipe in sorted(recipes, key=lambda r: r.get('slug') or r['id']):
        groups[dish_type(recipe)[0]].append(recipe)
    chosen, seen_cuisines, seen_meals = [], set(), set()
    while len(chosen) < size and any(groups.values()):
        for kind in sorted(groups, key=lambda k: -len(groups[k])):
            if not groups[kind] or len(chosen) >= size:
                continue
            # Prefer a recipe that adds a new cuisine or meal slot to the sample.
            pool = groups[kind]
            best = max(pool, key=lambda r: ((r.get('cuisine') not in seen_cuisines)
                                            + len(set(r.get('meal_types') or []) - seen_meals)))
            pool.remove(best)
            chosen.append(best)
            seen_cuisines.add(best.get('cuisine'))
            seen_meals.update(best.get('meal_types') or [])
    return chosen


def select(recipes, options, *, curated=frozenset(), clock=None):
    if options.recipes:
        wanted = set(options.recipes)
        chosen = [r for r in recipes if r['id'] in wanted or r.get('slug') in wanted]
        missing = wanted - {r['id'] for r in chosen} - {r.get('slug') for r in chosen}
        if missing:
            raise SystemExit(f'unknown recipe(s): {", ".join(sorted(missing))}')
        if not options.regenerate:
            chosen = [r for r in chosen if lifecycle.needs_image(r, curated=curated, clock=clock, retry_failed=True)]
    else:
        if options.regenerate:
            raise SystemExit('--regenerate needs explicit --recipe ids; approved images are never replaced in bulk')
        chosen = [r for r in recipes if lifecycle.needs_image(r, curated=curated, clock=clock,
                                                               retry_failed=options.retry_failed)]
        chosen.sort(key=lambda r: r.get('slug') or r['id'])
        if options.sample:
            chosen = representative_sample(chosen, options.sample)
    if options.limit:
        chosen = chosen[:options.limit]
    return chosen


def run(options, store, storage, provider, *, curated=frozenset(), clock=None, log=print):
    recipes = store.recipes()
    foods = store.foods()
    targets = select(recipes, options, curated=curated, clock=clock)
    summary = Summary(selected=len(targets))
    log(f'{len(targets)} recipe(s) selected out of {len(recipes)}')
    if options.dry_run:
        for recipe in targets:
            spec = build_prompt(recipe, foods)
            log(f'\n# {recipe.get("slug")} ({recipe["id"]}) status={lifecycle.status_of(recipe, curated)} '
                f'type={spec.dish_type}\n{spec.text}')
        return summary
    if not targets:
        return summary

    provider.check()  # fails before anything is claimed or written
    storage.ensure_bucket()
    for recipe in targets:
        recipe_id = recipe['id']
        summary.processed += 1
        spec = build_prompt(recipe, foods)
        try:
            claimed = store.update(recipe_id, lambda data: lifecycle.claim(
                data, clock=clock, regenerate=options.regenerate, curated=curated,
                retry_failed=options.retry_failed or bool(options.recipes)))
        except lifecycle.Ineligible as reason:
            summary.skipped += 1
            log(f'skip {recipe.get("slug")}: {reason}')
            continue
        generation = claimed['image_source']['generation']
        try:
            seed = lifecycle.seed_for(recipe_id, generation)
            image = provider.generate(spec.text, seed, *SOURCE_SIZE, short_prompt=spec.short)
            asset = validate(optimize(image))
            summary.generated += 1
            path = lifecycle.storage_path(recipe_id, generation)
            if options.output_dir:
                _keep_local(options.output_dir, path, image, asset)
            url = storage.upload(path, asset.data)
            summary.uploaded += 1
            candidate = {
                'generation': generation, 'path': path, 'url': url, 'format': 'webp',
                'prompt': spec.text, 'clip_prompt': spec.short, 'prompt_version': PROMPT_VERSION, 'dish_type': spec.dish_type,
                'seed': seed, **provider.metadata(),
                'source_width': asset.source_width, 'source_height': asset.source_height,
                'width': asset.width, 'height': asset.height, 'bytes': asset.bytes, 'quality': asset.quality,
                'sha256': asset.sha256, 'pipeline_version': lifecycle.PIPELINE_VERSION,
                'generated_at': lifecycle.now_iso(clock),
            }
            store.update(recipe_id, lambda data: lifecycle.complete(data, candidate, clock=clock))
            log(f'generated {recipe.get("slug")} -> {path} ({asset.bytes} bytes)')
        except Exception as error:  # one bad recipe must not stop the batch
            summary.failed += 1
            summary.failures.append((recipe.get('slug') or recipe_id, str(error)))
            message = f'{type(error).__name__}: {error}'
            log(f'FAILED {recipe.get("slug")}: {message}')
            try:
                store.update(recipe_id, lambda data, message=message: lifecycle.fail(
                    data, message, generation=generation, clock=clock))
            except lifecycle.Ineligible:
                pass
    return summary


def _keep_local(directory, path, image, asset):
    target = Path(directory) / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(asset.data)
    buffer = io.BytesIO()
    image.save(buffer, 'PNG')
    target.with_suffix('.source.png').write_bytes(buffer.getvalue())


PAST = {'approve': 'approved', 'reject': 'rejected', 'queue': 'queued'}


def review(store, *, action, recipe_ids, reason='', reviewer=None, curated=frozenset(), clock=None, log=print):
    """Approve, reject or queue explicit recipes. Returns the number changed."""
    by_key = {}
    for recipe in store.recipes():
        by_key[recipe['id']] = recipe
        if recipe.get('slug'):
            by_key[recipe['slug']] = recipe
    changed = 0
    for key in recipe_ids:
        recipe = by_key.get(key)
        if recipe is None:
            log(f'unknown recipe {key}')
            continue
        if action == 'approve':
            change = lambda data: lifecycle.approve(data, clock=clock, reviewer=reviewer)  # noqa: E731
        elif action == 'reject':
            change = lambda data: lifecycle.reject(data, reason=reason, clock=clock)  # noqa: E731
        elif action == 'queue':
            change = lambda data: lifecycle.queue(data, clock=clock, curated=curated)  # noqa: E731
        else:
            raise ValueError(action)
        try:
            store.update(recipe['id'], change)
            changed += 1
            log(f'{PAST[action]} {recipe.get("slug")}')
        except lifecycle.Ineligible as why:
            log(f'cannot {action} {recipe.get("slug")}: {why}')
    return changed


def status_report(recipes, curated=frozenset()):
    counts = defaultdict(int)
    for recipe in recipes:
        counts[lifecycle.status_of(recipe, curated)] += 1
    return dict(sorted(counts.items()))


def review_sheet(recipes, path):
    """Write a static HTML page with every candidate awaiting review."""
    rows = []
    for recipe in sorted(recipes, key=lambda r: r.get('slug') or ''):
        source = lifecycle.source_of(recipe)
        candidate = source.get('candidate') or {}
        if source.get('status') != 'generated' or not candidate.get('url'):
            continue
        title = (recipe.get('title') or {}).get('en') or recipe.get('slug')
        rows.append(f'<figure><img src="{_escape(candidate["url"])}" loading="lazy" alt="">'
                    f'<figcaption><b>{_escape(title)}</b><br><code>{_escape(recipe.get("slug") or "")}</code>'
                    f' · gen {candidate.get("generation")} · seed {candidate.get("seed")}'
                    f'<details><summary>prompt</summary>{_escape(candidate.get("prompt", ""))}</details>'
                    f'</figcaption></figure>')
    Path(path).write_text(
        '<!doctype html><meta charset="utf-8"><title>EatMe recipe images to review</title>'
        '<style>body{font-family:system-ui;margin:16px;background:#faf8f4}main{display:grid;gap:16px;'
        'grid-template-columns:repeat(auto-fill,minmax(320px,1fr))}figure{margin:0;background:#fff;'
        'border-radius:12px;overflow:hidden}img{width:100%;aspect-ratio:1.6;object-fit:cover}'
        'figcaption{padding:8px 12px;font-size:13px}</style>'
        f'<h1>{len(rows)} image(s) awaiting review</h1><main>{"".join(rows)}</main>')
    return len(rows)


def _escape(text):
    return str(text).replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;')


__all__ = ['Options', 'Summary', 'run', 'select', 'review', 'status_report', 'review_sheet', 'representative_sample',
           'InvalidImage', 'ASSET_SIZE']
