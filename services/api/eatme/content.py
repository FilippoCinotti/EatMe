"""Private recipes, favorites, feedback, substitutions and product lookup."""
from collections import Counter
from html.parser import HTMLParser
import json
from datetime import datetime, timedelta, timezone

from .auth import now
from .engine import amount_milli, compatibility, quantity, requirements
from .errors import DomainError
from .providers import OpenFoodFacts, barcode, https_request
from .storage import decode, encode
from .validation import integer, new_id, text, valid_uuid


class RecipeParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.recording, self.parts, self.documents = False, [], []

    def handle_starttag(self, tag, attrs):
        if tag == "script" and dict(attrs).get("type", "").lower() == "application/ld+json":
            self.recording, self.parts = True, []

    def handle_data(self, data):
        if self.recording:
            self.parts.append(data)

    def handle_endtag(self, tag):
        if tag == "script" and self.recording:
            self.recording = False
            try:
                self.documents.append(json.loads("".join(self.parts)))
            except ValueError:
                pass


def find_recipe(value):
    if isinstance(value, dict):
        kind = value.get("@type", [])
        if kind == "Recipe" or (isinstance(kind, list) and "Recipe" in kind):
            return value
        for child in value.values():
            result = find_recipe(child)
            if result:
                return result
    elif isinstance(value, list):
        for child in value:
            result = find_recipe(child)
            if result:
                return result
    return None


class ContentService:
    def recipes(self, user_id):
        with self.db.transaction() as tx:
            self._member(tx, user_id)
            _, recipes, _, _ = self._catalog(tx, user_id)
            favorites = {r["recipe_id"] for r in tx.all("SELECT recipe_id FROM recipe_favorites WHERE user_id=?", (user_id,))}
            return {"items": [{**r, "favorite": r["id"] in favorites} for r in recipes]}

    def recipe_action(self, user_id, data, key):
        with self.db.transaction() as tx:
            profile, foods, recipes, rules, _, _ = self._context(tx, user_id)
            def save():
                action = data.get("action")
                recipe_id = data.get("recipe_id")
                recipe = next((r for r in recipes if r["id"] == recipe_id), None)
                if action in {"favorite", "feedback", "substitute", "delete"} and not recipe:
                    raise DomainError("recipe_not_found", 404)
                if action == "favorite":
                    if type(data.get("enabled")) is not bool:
                        raise DomainError("invalid_favorite", 422)
                    if data["enabled"]:
                        tx.execute("INSERT INTO recipe_favorites VALUES (?,?,?) ON CONFLICT DO NOTHING", (user_id, recipe_id, now()))
                    else:
                        tx.execute("DELETE FROM recipe_favorites WHERE user_id=? AND recipe_id=?", (user_id, recipe_id))
                    return {"favorite": data["enabled"]}
                if action == "feedback":
                    rating = integer(data.get("rating"), minimum=-1, maximum=1)
                    reasons = data.get("reasons", [])
                    if not isinstance(reasons, list) or len(reasons) > 5 or any(r not in {"taste", "time", "ingredients", "difficulty", "variety"} for r in reasons):
                        raise DomainError("invalid_feedback", 422)
                    tx.execute("INSERT INTO recipe_feedback VALUES (?,?,?,?,?) ON CONFLICT(user_id,recipe_id) DO UPDATE SET rating=excluded.rating,reasons=excluded.reasons,updated_at=excluded.updated_at", (user_id, recipe_id, rating, encode(reasons), now()))
                    return {"saved": True}
                if action == "delete":
                    owned = tx.one("SELECT 1 FROM content_ownership WHERE kind='recipe' AND content_id=? AND user_id=?", (recipe_id, user_id))
                    if not owned:
                        raise DomainError("forbidden", 403)
                    if tx.one("SELECT 1 FROM cooking_sessions WHERE recipe_id=?", (recipe_id,)):
                        raise DomainError("recipe_has_cooking_history", 409)
                    tx.execute("DELETE FROM content_ownership WHERE kind='recipe' AND content_id=?", (recipe_id,))
                    tx.execute("DELETE FROM recipes WHERE id=?", (recipe_id,))
                    return {"deleted": True}
                if action == "substitute":
                    original, replacement = valid_uuid(data.get("food_id")), valid_uuid(data.get("replacement_id"))
                    if replacement not in foods or original not in {i["food_id"] for i in recipe["ingredients"]}:
                        raise DomainError("invalid_substitution", 422)
                    amount = quantity(amount_milli(data.get("quantity")))
                    value = {**recipe, "ingredients": [{"food_id": replacement, "quantity": amount} if i["food_id"] == original else i for i in recipe["ingredients"]]}
                    # A replacement is a new private recipe; it never edits the original catalog.
                    value["provenance"] = "user-substitution"
                    return {**value,"requires_step_review":True}
                elif action == "save":
                    value = data.get("recipe")
                else:
                    raise DomainError("invalid_action", 422)
                value = self._validate_recipe(value, foods)
                assessment = compatibility([i["food_id"] for i in value["ingredients"]], foods, profile["settings"], rules)
                if assessment["reasons"]:
                    raise DomainError("recipe_not_compatible", 409, assessment)
                identifier = new_id()
                value.update(id=identifier, is_demo=False, private=True)
                tx.execute("INSERT INTO recipes VALUES (?,?)", (identifier, encode(value)))
                tx.execute("INSERT INTO content_ownership VALUES ('recipe',?,?,NULL)", (identifier, user_id))
                return value
            return self._once(tx, user_id, key, "recipes", data, save)

    def _validate_recipe(self, value, foods):
        if not isinstance(value, dict):
            raise DomainError("invalid_recipe", 422)
        title = value.get("title")
        title = {"en": title, "it": title} if isinstance(title, str) else title
        if not isinstance(title, dict):
            raise DomainError("invalid_recipe", 422)
        title = {lang: text(title.get(lang) or title.get("en"), maximum=160) for lang in ("en", "it")}
        steps = value.get("steps")
        if isinstance(steps, list):
            steps = {"en": steps, "it": steps}
        if not isinstance(steps, dict):
            raise DomainError("invalid_recipe", 422)
        normalized = {}
        for lang in ("en", "it"):
            items = steps.get(lang) or steps.get("en")
            if not isinstance(items, list) or not 1 <= len(items) <= 30:
                raise DomainError("invalid_recipe_steps", 422)
            normalized[lang] = [text(s, maximum=2000) for s in items]
        ingredients = value.get("ingredients")
        if not isinstance(ingredients, list) or not 1 <= len(ingredients) <= 40:
            raise DomainError("invalid_ingredients", 422)
        items = []
        for item in ingredients:
            if not isinstance(item, dict) or item.get("food_id") not in foods:
                raise DomainError("unknown_ingredient", 422)
            amount = amount_milli(item.get("quantity"))
            if foods[item["food_id"]]["unit"] == "pcs" and amount % 1000:
                raise DomainError("whole_units_required", 422)
            items.append({"food_id": item["food_id"], "quantity": quantity(amount)})
        return {"title": title, "steps": normalized, "ingredients": items, "servings": integer(value.get("servings"), minimum=1, maximum=20), "minutes": integer(value.get("minutes"), minimum=1, maximum=1440), "cuisine": text(value.get("cuisine", "other"), maximum=60), "provenance": text(value.get("provenance", "user-import"), maximum=60), "source_url": text(value.get("source_url", ""), maximum=2000, empty=True), "nutrition": None}

    def import_url(self, user_id, data):
        self._household(user_id)
        if data.get("private_use_confirmed") is not True:
            raise DomainError("private_use_confirmation_required", 422)
        url = text(data.get("url"), maximum=2000)
        parser = RecipeParser()
        parser.feed(https_request(url).decode("utf-8", errors="replace"))
        recipe = find_recipe(parser.documents)
        if not recipe:
            raise DomainError("recipe_metadata_not_found", 422)
        return {"title": str(recipe.get("name", ""))[:160], "ingredients_text": recipe.get("recipeIngredient", [])[:40], "instructions": recipe.get("recipeInstructions", []), "source_url": url, "requires_mapping": True}

    def product(self, user_id, code):
        if not self.feature_enabled('barcode_scan'):
            raise DomainError('product_provider_not_configured', 503)
        self._household(user_id)
        code = barcode(code)
        with self.db.transaction() as tx:
            existing = tx.one("SELECT * FROM food_products WHERE barcode=?", (code,))
            if existing and existing["updated_at"] > (datetime.now(timezone.utc) - timedelta(days=7)).isoformat():
                return {**decode(existing["data"]), "id": existing["id"]}
        value = (getattr(self, "product_provider", None) or OpenFoodFacts()).lookup(code)
        with self.db.transaction() as tx:
            identifier = existing["id"] if existing else new_id()
            tx.execute("INSERT INTO food_products VALUES (?,?,NULL,?,1,?) ON CONFLICT(barcode) DO UPDATE SET data=excluded.data,updated_at=excluded.updated_at,version=food_products.version+1", (identifier, code, encode(value), now()))
            return {**value, "id": identifier}

    def insights(self, user_id):
        home = self._household(user_id)
        with self.db.transaction() as tx:
            rows = tx.all("SELECT kind,delta_milli,created_at FROM inventory_events WHERE household_id=? ORDER BY created_at DESC LIMIT 2000", (home,))
            counts = Counter(r["kind"] for r in rows)
            sessions = tx.all("SELECT recipe_id FROM cooking_sessions WHERE user_id=? ORDER BY created_at DESC LIMIT 100", (user_id,))
            return {"inventory_event_counts": dict(counts), "cooked_meals": len(sessions), "different_recipes": len({r["recipe_id"] for r in sessions}), "window": "latest_2000_events_and_100_meals", "money_saved": None, "carbon_saved": None}

    def recipe_nutrition(self, recipe, foods, servings):
        from decimal import Decimal
        totals, missing, sources, coverage, units = {}, [], {}, {}, {}
        needed = requirements(recipe, servings)
        for food_id, amount in needed.items():
            food = foods[food_id]
            nutrients = food.get("nutrition")
            if not nutrients or not nutrients.get('values') or food["unit"] == "pcs" or nutrients.get("basis") != "100" + food["unit"]:
                missing.append(food_id)
                continue
            sources[food_id] = nutrients.get('source_url')
            for name, value in nutrients['values'].items():
                if name in units and units[name] != value['unit']:
                    raise DomainError('inconsistent_nutrition_units', 409)
                units[name] = value['unit']
                totals[name] = totals.get(name, Decimal(0)) + Decimal(str(value['value'])) * amount / 100000
                coverage[name] = coverage.get(name, 0) + 1
        return {'totals': {name: {'value': str(amount.quantize(Decimal('0.01'))), 'unit': units[name], 'complete': coverage[name] == len(needed)} for name, amount in totals.items()}, 'servings': servings, 'complete': bool(totals) and not missing and all(n == len(needed) for n in coverage.values()), 'missing_food_ids': missing, 'sources': sources, 'method': 'ingredient_amounts_no_cooking_retention_adjustment'}

    def product_stock(self, user_id, data, key):
        home = self._household(user_id, write=True)
        with self.db.transaction(home) as tx:
            def save():
                self._member(tx, user_id, home, write=True)
                row = tx.one('SELECT * FROM food_products WHERE id=?', (valid_uuid(data.get('product_id')),))
                if not row:
                    raise DomainError('product_not_found', 404)
                if data.get('package_checked') is not True:
                    raise DomainError('package_confirmation_required', 422)
                product = decode(row['data'])
                amount = amount_milli(data.get('quantity'))
                if amount % 1000:
                    raise DomainError('whole_units_required', 422)
                from .catalog import identifier
                food_id = identifier('product-food', row['barcode'])
                food = {'id': food_id, 'name': {'en': product['name'], 'it': product['name']}, 'group': 'packaged', 'unit': 'pcs', 'ingredient_status': 'unknown', 'allergens': [], 'may_contain': [], 'intolerances': [], 'nutrition': product.get('nutrition'), 'provenance': 'openfoodfacts-unreviewed', 'is_demo': False}
                # Packaged foods cannot inherit the safety assessment of a generic ingredient.
                tx.execute('INSERT INTO foods VALUES (?,?) ON CONFLICT DO NOTHING', (food_id, encode(food)))
                batch_id, stamp = new_id(), now()
                tx.execute('INSERT INTO inventory_batches VALUES (?,?,?,?,?,?,?,?,?,?,?,?)', (batch_id, home, food_id, amount, 'fridge', None, 'unknown', None, 'barcode-confirmed', 1, stamp, stamp))
                tx.execute('INSERT INTO inventory_metadata VALUES (?,?,?)', (batch_id, encode({'barcode': row['barcode'], 'product_id': row['id'], 'lot': text(data.get('lot', ''), maximum=100, empty=True), 'ingredients_unreviewed': True}), stamp))
                self._event(tx, user_id, home, batch_id, 'created', amount)
                duplicates = tx.one('SELECT COUNT(*) AS n FROM inventory_batches WHERE household_id=? AND food_id=? AND quantity_milli>0', (home, food_id))['n'] - 1
                return {'id': batch_id, 'version': 1, 'existing_batches': duplicates, 'assessment': 'unknown_ingredients'}
            return self._once(tx, user_id, key, 'product_stock', data, save)
