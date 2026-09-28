"""Household pantry staples: basics assumed always available, never quantity-tracked."""
from .auth import now
from .errors import DomainError
from .storage import decode, encode
from .validation import valid_uuid

# Offered at setup, in this order, when present in the food catalog.
STAPLE_SUGGESTIONS = (
    "olive-oil", "sunflower-oil", "black-pepper", "wheat-flour", "white-sugar", "brown-sugar",
    "vinegar", "balsamic", "garlic", "onion", "baking-powder", "baking-soda", "yeast", "cornstarch",
    "oregano", "chili-flakes", "paprika", "cinnamon", "nutmeg", "cumin", "curry-powder", "bay-leaf",
    "rosemary", "thyme", "vanilla", "honey", "soy-sauce", "dijon-mustard", "tomato-paste",
    "breadcrumbs", "rice", "pasta",
)
MAX_STAPLES = 80


class PantryService:
    def _staples(self, tx, household_id) -> set[str]:
        row = tx.one("SELECT data FROM household_pantry WHERE household_id=?", (household_id,))
        return set(decode(row["data"]).get("food_ids", [])) if row else set()

    def pantry(self, user_id):
        household_id = self._household(user_id)
        with self.db.transaction() as tx:
            self._member(tx, user_id, household_id)
            foods = self._catalog(tx, user_id)[0]
            row = tx.one("SELECT data,version FROM household_pantry WHERE household_id=?", (household_id,))
            ids = [f for f in (decode(row["data"]).get("food_ids", []) if row else []) if f in foods]
            by_slug = {food.get("slug"): food for food in foods.values()}
            return {"food_ids": ids, "items": [foods[f] for f in ids], "version": row["version"] if row else 0,
                    "configured": bool(row),
                    "suggestions": [by_slug[s] for s in STAPLE_SUGGESTIONS if s in by_slug]}

    def pantry_action(self, user_id, data, key):
        household_id = self._household(user_id, write=True)
        with self.db.transaction(household_id) as tx:
            def change():
                self._member(tx, user_id, household_id, write=True)
                if data.get("action") != "set":
                    raise DomainError("invalid_action", 422)
                food_ids = data.get("food_ids")
                if not isinstance(food_ids, list) or len(food_ids) > MAX_STAPLES:
                    raise DomainError("invalid_pantry", 422)
                foods = self._catalog(tx, user_id)[0]
                ids = list(dict.fromkeys(valid_uuid(f) for f in food_ids))
                if any(f not in foods for f in ids):
                    raise DomainError("invalid_food", 404)
                row = tx.one("SELECT version FROM household_pantry WHERE household_id=?", (household_id,))
                current = row["version"] if row else 0
                if data.get("expected_version", 0) != current:
                    raise DomainError("stale_pantry", 409)
                payload = encode({"food_ids": ids})
                if row:
                    tx.execute("UPDATE household_pantry SET data=?,version=version+1,updated_at=? WHERE household_id=?",
                               (payload, now(), household_id))
                else:
                    tx.execute("INSERT INTO household_pantry VALUES (?,?,?,?)", (household_id, payload, 1, now()))
                return {"food_ids": ids, "version": current + 1}
            return self._once(tx, user_id, key, "pantry", data, change)
