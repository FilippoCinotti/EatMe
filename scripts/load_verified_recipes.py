"""Upsert the source-verified recipe catalog into PostgreSQL/Supabase.

Usage:
  CATALOG_DATABASE_URL=postgresql://... python scripts/load_verified_recipes.py [--apply]

Without --apply the script only validates the catalog against the live food
table and prints what would change. Rows are keyed by deterministic ids, so
re-running is idempotent. Quantities are stored in each food's own catalog unit
(g, ml or pcs) using the per-ingredient conversion hints shipped in the file.

Catalog foods shipped in the file ("foods") are inserted when the database has
no food with the same slug; when it does, recipes are pointed at that food.
"""
import argparse
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'generated' / 'verified_recipes_catalog.json'


def quantity_for(unit, item):
    if unit == 'pcs':
        return str(max(1, round(item['pcs'] if item.get('pcs') else item['grams'] / (item.get('piece_g') or 50))))
    value = item['grams'] / (item.get('density') or 1) if unit == 'ml' else item['grams']
    if value >= 100:
        return str(int(round(value / 5.0) * 5))
    if value >= 20:
        return str(int(round(value)))
    return f'{max(value, 0.1):.1f}'.rstrip('0').rstrip('.')


KEEP_FROM_DATABASE = ('image_url', 'image_source')


def plan_foods(catalog, foods):
    """Return (foods_to_insert, id_remap, merged_foods) for catalog-shipped foods."""
    by_slug = {food.get('slug'): food_id for food_id, food in foods.items() if food.get('slug')}
    inserts, remap, merged = [], {}, dict(foods)
    for food in catalog.get('foods', []):
        current = by_slug.get(food['slug'])
        if current and current != food['id']:
            remap[food['id']] = current
        elif food['id'] not in foods:
            inserts.append(food)
            merged[food['id']] = food
    return inserts, remap, merged


def build_rows(catalog, foods, existing=None, remap=None):
    """existing maps recipe id -> stored data; generated images already attached there are kept."""
    existing, remap = existing or {}, remap or {}
    rows, skipped = [], []
    for recipe in catalog['recipes']:
        recipe = recipe | {'ingredients': [item | {'food_id': remap.get(item['food_id'], item['food_id'])}
                                           for item in recipe['ingredients']]}
        missing = [item['food_id'] for item in recipe['ingredients'] if item['food_id'] not in foods]
        if missing:
            skipped.append((recipe['slug'], missing))
            continue
        data = {key: value for key, value in recipe.items() if key != 'ingredients'}
        data['ingredients'] = [
            {'food_id': item['food_id'], 'quantity': quantity_for(foods[item['food_id']].get('unit', 'g'), item)}
            for item in recipe['ingredients']
        ]
        for key in KEEP_FROM_DATABASE:
            if not data.get(key) and existing.get(recipe['id'], {}).get(key):
                data[key] = existing[recipe['id']][key]
        rows.append(data)
    return rows, skipped


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--apply', action='store_true', help='write rows (default: dry run)')
    parser.add_argument('--catalog', default=str(CATALOG))
    args = parser.parse_args()
    url = os.environ.get('CATALOG_DATABASE_URL') or os.environ.get('DATABASE_URL')
    if not url:
        sys.exit('Set CATALOG_DATABASE_URL (a PostgreSQL connection string with write access to recipes).')
    catalog = json.loads(Path(args.catalog).read_text())

    import psycopg

    with psycopg.connect(url) as connection:
        foods = {row[0]: json.loads(row[1]) for row in connection.execute('SELECT id, data FROM foods')}
        existing = {row[0]: json.loads(row[1]) for row in connection.execute('SELECT id, data FROM recipes')}
        inserts, remap, foods = plan_foods(catalog, foods)
        rows, skipped = build_rows(catalog, foods, existing, remap)
        new = sum(row['id'] not in existing for row in rows)
        print(f'foods: {len(inserts)} to insert, {len(remap)} matched to existing foods by slug')
        print(f'catalog v{catalog["catalog_version"]}: {len(catalog["recipes"])} recipes; '
              f'{len(rows)} loadable ({new} new, {len(rows) - new} updates); {len(skipped)} skipped for unknown foods')
        for slug, missing in skipped[:20]:
            print('  skip', slug, missing)
        if not args.apply:
            print('Dry run: pass --apply to write.')
            return
        with connection.transaction():
            for food in inserts:
                connection.execute(
                    'INSERT INTO foods(id, data) VALUES (%s, %s) ON CONFLICT(id) DO NOTHING',
                    (food['id'], json.dumps(food, sort_keys=True, ensure_ascii=False, separators=(',', ':'))),
                )
            for row in rows:
                connection.execute(
                    'INSERT INTO recipes(id, data) VALUES (%s, %s) '
                    'ON CONFLICT(id) DO UPDATE SET data = excluded.data',
                    (row['id'], json.dumps(row, sort_keys=True, ensure_ascii=False, separators=(',', ':'))),
                )
        print(f'Inserted {len(inserts)} foods; upserted {len(rows)} recipes.')


if __name__ == '__main__':
    main()
