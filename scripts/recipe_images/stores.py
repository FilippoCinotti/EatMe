"""Where recipes are read from and where image state is written.

``PostgresStore`` is the production store (``CATALOG_DATABASE_URL``). It only
selects public catalog recipes (never user-owned ones) and updates a single
recipe at a time under a row lock, touching only ``image_url`` and
``image_source`` inside the JSON document. ``CatalogFileStore`` reads the
repository catalog for dry runs without database access.
"""
from __future__ import annotations

import json
from pathlib import Path


class ReadOnlyStore(RuntimeError):
    pass


def _apply(data, change):
    """Return ``data`` with only image_url and image_source replaced by ``change``."""
    image_url, image_source = change(dict(data))
    return {**data, 'image_url': image_url or None, 'image_source': image_source}


class MemoryStore:
    def __init__(self, recipes, foods):
        self.rows = {r['id']: json.loads(json.dumps(r)) for r in recipes}
        self.food_rows = foods
        self.writes = []

    def recipes(self):
        return [json.loads(json.dumps(r)) for r in self.rows.values()]

    def foods(self):
        return self.food_rows

    def update(self, recipe_id, change):
        updated = _apply(self.rows[recipe_id], change)
        self.rows[recipe_id] = updated
        self.writes.append((recipe_id, updated.get('image_source', {}).get('status')))
        return updated


class CatalogFileStore(MemoryStore):
    """The committed catalog JSON; read-only, for dry runs."""

    def __init__(self, root):
        root = Path(root)
        catalog = json.loads((root / 'generated/verified_recipes_catalog.json').read_text())
        foods = {f['id']: f for f in json.loads((root / 'scripts/catalog_image_targets.json').read_text())}
        foods.update({f['id']: f for f in catalog.get('foods', [])})
        super().__init__(catalog['recipes'], foods)

    def update(self, recipe_id, change):
        raise ReadOnlyStore('the catalog file is read-only; use CATALOG_DATABASE_URL to generate images')


class PostgresStore:
    PUBLIC_RECIPES = ("SELECT r.id, r.data FROM recipes r WHERE NOT EXISTS (SELECT 1 FROM content_ownership o "
                      "WHERE o.kind = 'recipe' AND o.content_id = r.id) ORDER BY r.id")

    def __init__(self, url):
        import psycopg
        self.connection = psycopg.connect(url)

    def recipes(self):
        with self.connection.transaction():
            rows = self.connection.execute(self.PUBLIC_RECIPES).fetchall()
        recipes = [json.loads(data) for _, data in rows]
        return [r for r in recipes if not r.get('archived') and not r.get('private')]

    def foods(self):
        with self.connection.transaction():
            rows = self.connection.execute('SELECT id, data FROM foods').fetchall()
        return {food_id: json.loads(data) for food_id, data in rows}

    def update(self, recipe_id, change):
        with self.connection.transaction():
            row = self.connection.execute('SELECT data FROM recipes WHERE id = %s FOR UPDATE', (recipe_id,)).fetchone()
            if row is None:
                raise KeyError(recipe_id)
            updated = _apply(json.loads(row[0]), change)
            self.connection.execute('UPDATE recipes SET data = %s WHERE id = %s',
                                    (json.dumps(updated, ensure_ascii=False), recipe_id))
        return updated

    def close(self):
        self.connection.close()
