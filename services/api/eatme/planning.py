"""Transactional shopping, weekly plans, and leftover lifecycle."""
from collections import Counter
from datetime import date, timedelta

from .auth import now
from .engine import (
    amount_milli,
    batch_usable,
    compatibility,
    primary_food_id,
    quantity,
    rank,
    requirements,
    substantiality,
)
from .errors import DomainError
from .storage import decode, encode
from .validation import choice, integer, new_id, text, valid_date, valid_uuid


PLAN_SLOTS = ("breakfast", "lunch", "snack", "dinner")
RECIPE_MEAL_TYPES = {
    "breakfast": {"breakfast"},
    "lunch": {"lunch"},
    "snack": {"snack", "merenda"},
    "dinner": {"dinner"},
}


def weekly_meals(ranked, start, servings, participants, enabled_slots, foods=None, *, locked=(), daily_limits=None):
    """Build the most varied compatible week available for enabled meal slots.

    Some catalogs may not cover every slot. Those slots are deliberately left
    empty instead of assigning a semantically wrong recipe. A recipe is not
    repeated until every eligible alternative for that slot has been used.
    Primary ingredients and cuisines are balanced before the base ranking is
    used as a tie-breaker.
    """
    pools = {
        slot: [
            item
            for item in ranked
            if RECIPE_MEAL_TYPES[slot] & set(item["recipe"].get("meal_types", []))
        ]
        for slot in enabled_slots
    }
    foods = foods or {}
    locked_by_slot = {(m["date"], m["slot"]): m for m in locked}
    recipe_counts = Counter(m["recipe_id"] for m in locked)
    by_id = {item["recipe"]["id"]: item["recipe"] for item in ranked}
    primary_counts = Counter(primary_food_id(by_id[m["recipe_id"]], foods) for m in locked if m["recipe_id"] in by_id)
    cuisine_counts = Counter(by_id[m["recipe_id"]].get("cuisine", "") for m in locked if m["recipe_id"] in by_id)
    previous_by_slot = {}
    meals = list(locked)
    week = date.fromisoformat(start)
    for day_offset in range(7):
        for slot in enabled_slots:
            day = (week + timedelta(days=day_offset)).isoformat()
            if (day, slot) in locked_by_slot:
                continue
            limit = (daily_limits or {}).get(day)
            pool = [item for item in pools[slot] if limit is None or item["recipe"]["minutes"] <= limit]
            if not pool:
                continue
            fresh = [item for item in pool if not recipe_counts[item["recipe"]["id"]]]
            candidates = fresh or pool

            def variety_key(item):
                recipe = item["recipe"]
                primary = primary_food_id(recipe, foods)
                cuisine = recipe.get("cuisine", "")
                previous_primary, previous_cuisine = previous_by_slot.get(slot, (None, None))
                substance = (
                    item.get("component_scores", {}).get("substantiality", 0)
                    if slot in {"lunch", "dinner"}
                    else 0
                )
                return (
                    recipe_counts[recipe["id"]],
                    primary_counts[primary],
                    cuisine_counts[cuisine],
                    primary == previous_primary,
                    cuisine == previous_cuisine,
                    -substance,
                    -item.get("score", 0),
                    recipe["id"],
                )

            selected = min(candidates, key=variety_key)
            recipe = selected["recipe"]
            primary = primary_food_id(recipe, foods)
            cuisine = recipe.get("cuisine", "")
            recipe_counts[recipe["id"]] += 1
            primary_counts[primary] += 1
            cuisine_counts[cuisine] += 1
            previous_by_slot[slot] = (primary, cuisine)
            meals.append({
                "date": (week + timedelta(days=day_offset)).isoformat(),
                "slot": slot,
                "recipe_id": recipe["id"],
                "servings": servings,
                "participants": participants,
            })
    return meals


def preference_mode(overrides, day, slot):
    """Resolve a temporary ranking context without changing a profile."""
    for override in overrides or []:
        if override.get("mode") != "guilty_pleasure" or override.get("date") != day:
            continue
        if override.get("scope") == "day" or (
            override.get("scope") == "meal" and override.get("slot") == slot
        ):
            return "guilty_pleasure"
    return "for_you"


class PlanningService:
    def _preference_overrides(self, value, start, meals):
        if value is None:
            return []
        if not isinstance(value, list) or len(value) > 14:
            raise DomainError("invalid_preference_override", 422)
        week = date.fromisoformat(start)
        meal_keys = {(meal.get("date"), meal.get("slot")) for meal in meals}
        normalized, targets = [], set()
        for raw in value:
            if not isinstance(raw, dict) or raw.get("mode") != "guilty_pleasure":
                raise DomainError("invalid_preference_override", 422)
            scope = choice(raw.get("scope", "meal"), {"meal", "day"})
            day = valid_date(raw.get("date"))
            if not day or not 0 <= (date.fromisoformat(day) - week).days < 7:
                raise DomainError("invalid_preference_override", 422)
            slot = None
            if scope == "meal":
                slot = choice(raw.get("slot"), {"breakfast", "lunch", "dinner", "snack"})
                if (day, slot) not in meal_keys:
                    raise DomainError("invalid_preference_override", 422)
            target = (scope, day, slot)
            if target in targets:
                raise DomainError("duplicate_preference_override", 422)
            targets.add(target)
            normalized.append({"mode": "guilty_pleasure", "scope": scope, "date": day, **({"slot": slot} if slot else {})})
        return normalized

    def _shopping_purchases(self, tx, home):
        totals = Counter()
        for row in tx.all("SELECT delta_milli,metadata FROM inventory_events WHERE household_id=? AND kind='purchased'", (home,)):
            identifier = decode(row["metadata"]).get("shopping_item_id")
            if identifier:
                totals[identifier] += row["delta_milli"]
        return totals

    def shopping(self, user_id):
        with self.db.transaction() as tx:
            home = self._member(tx, user_id)["household_id"]
            purchased = self._shopping_purchases(tx, home)
            return {"items": [{**r, "quantity": quantity(r["quantity_milli"]), "purchased_quantity": quantity(purchased[r["id"]]),
                               "requested_quantity": quantity(r["quantity_milli"] + purchased[r["id"]]), "checked": bool(r["checked"])} for r in tx.all("SELECT * FROM shopping_items WHERE household_id=? ORDER BY checked,category,label,id", (home,))]}

    def shopping_action(self, user_id, data, key):
        if data.get("action") in {"generate", "preview_generate"}:
            self.require_capability(user_id, "canUseGeneratedShopping")
        home = self._household(user_id, write=True)
        with self.db.transaction(home) as tx:
            def change():
                self._member(tx, user_id, home, write=True)
                action = data.get("action")
                if action == "add":
                    food_id = data.get("food_id")
                    food = self._catalog(tx, user_id, include_recipes=False)[0].get(valid_uuid(food_id)) if food_id else None
                    if food_id and not food:
                        raise DomainError("food_not_found", 404)
                    unit = food["unit"] if food else choice(data.get("unit", "pcs"), {"pcs", "g", "ml"})
                    label = text(data.get("label") or (food["name"]["en"] if food else None), maximum=120)
                    amount = amount_milli(data.get("quantity"))
                    if unit == "pcs" and amount % 1000:
                        raise DomainError("whole_units_required", 422)
                    identifier = self._shopping_insert(tx, user_id, home, food_id, label, amount, unit, text(data.get("category", food.get("group", "other") if food else "other"), maximum=40), "manual")
                    return {"id": identifier, "version": 1}
                if action in {"generate", "preview_generate"}:
                    meals = data.get("meals")
                    source = "recipes"
                    if data.get("plan_id"):
                        plan = tx.one("SELECT * FROM meal_plans WHERE id=? AND user_id=? AND household_id=?", (valid_uuid(data["plan_id"]), user_id, home))
                        if not plan:
                            raise DomainError("plan_not_found", 404)
                        meals, source = decode(plan["data"])["meals"], "plan:" + plan["id"]
                    if not isinstance(meals, list) or not 1 <= len(meals) <= 28:
                        raise DomainError("invalid_meals", 422)
                    if data.get("plan_id") and "plan_version" in data and data["plan_version"] != plan["version"]:
                        raise DomainError("stale_plan", 409)
                    totals, foods = {}, {}
                    for meal in meals:
                        checked, catalog = self._validate_meal(tx, user_id, meal)
                        foods.update(catalog)
                        for food_id, amount in requirements(checked, meal["servings"]).items():
                            totals[food_id] = totals.get(food_id, 0) + amount
                    today = self.today(self._profile(tx, user_id)["settings"])
                    inventory = self._inventory(tx, home)
                    inventory_versions = {b["id"]: b["version"] for b in inventory}
                    if "inventory_versions" in data and data["inventory_versions"] != inventory_versions:
                        raise DomainError("stale_inventory", 409)
                    for batch in inventory:
                        if batch_usable(batch, today) and batch["food_id"] in totals:
                            totals[batch["food_id"]] = max(0, totals[batch["food_id"]] - batch["quantity_milli"])
                    for food_id in self._staples(tx, home) & set(totals):
                        totals[food_id] = 0
                    current = tx.all("SELECT * FROM shopping_items WHERE household_id=?", (home,))
                    snapshot = {row["id"]: row["version"] for row in current}
                    purchased = self._shopping_purchases(tx, home)
                    protected = [row["id"] for row in current if row["checked"] or purchased[row["id"]]]
                    # Checked and partially purchased lines retain their confirmed history.
                    for row in current:
                        if row["source_key"] == source and row["checked"] and row["food_id"] in totals:
                            totals[row["food_id"]] = max(0, totals[row["food_id"]] - row["quantity_milli"])
                    proposed = [{"food_id": food_id, "quantity": quantity(amount), "unit": foods[food_id]["unit"],
                                 "label": foods[food_id]["name"], "category": foods[food_id].get("group", "other")}
                                for food_id, amount in totals.items() if amount]
                    if action == "preview_generate":
                        return {"preview": True, "items": proposed, "shopping_versions": snapshot,
                                "inventory_versions": inventory_versions,
                                **({"plan_version": plan["version"]} if data.get("plan_id") else {})}
                    if "shopping_versions" in data and data["shopping_versions"] != snapshot:
                        raise DomainError("stale_shopping_item", 409)
                    # Reuse a partial line for its new outstanding requirement instead of
                    # adding another line when stock was consumed after the purchase.
                    partial_foods = set()
                    for row in current:
                        if row["source_key"] != source or row["checked"] or not purchased[row["id"]]:
                            continue
                        food_id = row["food_id"]
                        if food_id in partial_foods:
                            raise DomainError("shopping_reconciliation_required", 409)
                        partial_foods.add(food_id)
                        amount = totals.get(food_id, 0)
                        if amount:
                            if amount != row["quantity_milli"]:
                                tx.execute("UPDATE shopping_items SET quantity_milli=?,version=version+1,updated_at=? WHERE id=?", (amount, now(), row["id"]))
                        else:
                            tx.execute("DELETE FROM shopping_items WHERE id=?", (row["id"],))
                        totals[food_id] = 0
                    # Replace only unconfirmed generated lines; manual and checked lines survive.
                    for row in current:
                        if row["source_key"] == source and row["id"] not in protected:
                            tx.execute("DELETE FROM shopping_items WHERE id=?", (row["id"],))
                    identifiers = []
                    for food_id, amount in totals.items():
                        if amount:
                            food = foods[food_id]
                            identifiers.append(self._shopping_insert(tx, user_id, home, food_id, food["name"]["en"], amount, food["unit"], food.get("group", "other"), source))
                    return {"ids": identifiers}
                if action == "purchase_many":
                    return self._purchase_many(tx, user_id, home, data)
                identifier = valid_uuid(data.get("id"))
                item = tx.one("SELECT * FROM shopping_items WHERE id=? AND household_id=?", (identifier, home))
                if not item:
                    raise DomainError("shopping_item_not_found", 404)
                if item["version"] != data.get("expected_version"):
                    raise DomainError("stale_shopping_item", 409)
                if action == "delete":
                    tx.execute("DELETE FROM shopping_items WHERE id=?", (identifier,))
                    return {"deleted": True}
                if action == "purchase":
                    if not item["food_id"]:
                        raise DomainError("canonical_food_required", 422)
                    location = choice(data.get("location", "fridge"), {"fridge", "pantry", "freezer"})
                    expiry = valid_date(data.get("expiry_date"))
                    kind = choice(data.get("expiry_kind", "unknown"), {"unknown", "use_by", "best_before", "estimated"})
                    if bool(expiry) != (kind != "unknown"):
                        raise DomainError("expiry_type_required", 422)
                    estimate = data.get("estimate_expiry", False)
                    if type(estimate) is not bool:
                        raise DomainError("invalid_purchase", 422)
                    batch_id, expiry, kind = self._purchase_line(tx, user_id, home, item, location, expiry, kind, estimate, data.get("purchase_quantity"))
                    remaining = tx.one("SELECT quantity_milli FROM shopping_items WHERE id=?", (item["id"],))
                    return {"batch_id": batch_id, "purchased": True, "expiry_date": expiry, "expiry_kind": kind,
                            "remaining_quantity": quantity(remaining["quantity_milli"]) if remaining else "0"}
                if action == "check":
                    if type(data.get("checked")) is not bool:
                        raise DomainError("invalid_checked", 422)
                    tx.execute("UPDATE shopping_items SET checked=?,version=version+1,updated_at=? WHERE id=?", (int(data["checked"]), now(), identifier))
                elif action == "edit":
                    amount = amount_milli(data.get("quantity"))
                    if item["unit"] == "pcs" and amount % 1000:
                        raise DomainError("whole_units_required", 422)
                    tx.execute("UPDATE shopping_items SET label=?,quantity_milli=?,source_key='manual',version=version+1,updated_at=? WHERE id=?", (text(data.get("label", item["label"]), maximum=120), amount, now(), identifier))
                else:
                    raise DomainError("invalid_action", 422)
                return {"id": identifier, "version": item["version"] + 1}
            return self._once(tx, user_id, key, "shopping", data, change)

    def _purchase_line(self, tx, user_id, home, item, location, expiry, kind, estimate, purchase_quantity=None):
        """Move one shopping line into the fridge as a batch; returns (batch_id, expiry, kind)."""
        if estimate:
            food = self._catalog(tx, user_id, include_recipes=False)[0].get(item["food_id"])
            if food:
                expiry, kind = self._estimated_expiry(tx, user_id, food, location, expiry, kind)
        amount = item["quantity_milli"] if purchase_quantity is None else amount_milli(purchase_quantity)
        if item["unit"] == "pcs" and amount % 1000:
            raise DomainError("whole_units_required", 422)
        batch_id, stamp = new_id(), now()
        tx.execute("INSERT INTO inventory_batches VALUES (?,?,?,?,?,?,?,?,?,?,?,?)", (batch_id, home, item["food_id"], amount, location, expiry, kind, None, "shopping", 1, stamp, stamp))
        self._event(tx, user_id, home, batch_id, "purchased", amount, {"shopping_item_id": item["id"], "requested_milli": item["quantity_milli"]})
        remaining = max(0, item["quantity_milli"] - amount)
        if remaining:
            tx.execute("UPDATE shopping_items SET quantity_milli=?,checked=0,version=version+1,updated_at=? WHERE id=?", (remaining, stamp, item["id"]))
        else:
            tx.execute("DELETE FROM shopping_items WHERE id=?", (item["id"],))
        return batch_id, expiry, kind

    def _purchase_many(self, tx, user_id, home, data):
        """"I did the shopping": atomically move the selected lines into the fridge.

        Each line gets an estimated date from typical shelf life unless
        estimate_expiry is false. Lines without a catalog food are reported, not moved.
        """
        lines = data.get("items")
        if not isinstance(lines, list) or not 1 <= len(lines) <= 200:
            raise DomainError("invalid_items", 422)
        location = choice(data.get("location", "fridge"), {"fridge", "pantry", "freezer"})
        estimate = data.get("estimate_expiry", True)
        if type(estimate) is not bool:
            raise DomainError("invalid_purchase", 422)
        purchased, skipped, seen = [], [], set()
        for line in lines:
            if not isinstance(line, dict):
                raise DomainError("invalid_items", 422)
            identifier = valid_uuid(line.get("id"))
            if identifier in seen:
                raise DomainError("invalid_items", 422)
            seen.add(identifier)
            item = tx.one("SELECT * FROM shopping_items WHERE id=? AND household_id=?", (identifier, home))
            if not item:
                raise DomainError("shopping_item_not_found", 404, {"id": identifier})
            if item["version"] != line.get("expected_version"):
                raise DomainError("stale_shopping_item", 409, {"id": identifier})
            if not item["food_id"]:
                skipped.append({"id": identifier, "label": item["label"], "reason": "canonical_food_required"})
                continue
            batch_id, expiry, kind = self._purchase_line(tx, user_id, home, item, location, None, "unknown", estimate)
            purchased.append({"id": identifier, "batch_id": batch_id, "food_id": item["food_id"],
                              "expiry_date": expiry, "expiry_kind": kind})
        return {"purchased": purchased, "skipped": skipped}

    def _shopping_insert(self, tx, user_id, home, food_id, label, amount, unit, category, source):
        identifier, stamp = new_id(), now()
        tx.execute("INSERT INTO shopping_items VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)", (identifier, home, food_id, label, amount, unit, category, 0, source, 1, user_id, stamp, stamp))
        return identifier

    def _validate_meal(self, tx, user_id, meal):
        recipes, foods = self._validate_meals(tx, user_id, [meal])
        return recipes[0], foods

    def _validate_meals(self, tx, user_id, meals):
        profile = self._profile(tx, user_id)
        foods, recipes, _, versions = self._catalog(tx, user_id)
        today = self.today(profile["settings"])
        by_id = {recipe["id"]: recipe for recipe in recipes}
        diners, checked = {}, []
        for meal in meals:
            if not isinstance(meal, dict):
                raise DomainError("invalid_meal", 422)
            integer(meal.get("servings"), minimum=1, maximum=20)
            participants = meal.get("participants")
            # Validate before using the participant list as a cache key.
            if participants is not None and (not isinstance(participants, list) or any(not isinstance(p, str) for p in participants)):
                raise DomainError("invalid_participants", 422)
            key = tuple(participants) if participants is not None else (user_id,)
            if key not in diners:
                diners[key] = self._diners(tx, user_id, participants, profile, versions, today)
            settings, rules, _, _ = diners[key]
            recipe = by_id.get(meal.get("recipe_id"))
            if not recipe:
                raise DomainError("recipe_not_found", 404)
            assessment = compatibility([i["food_id"] for i in recipe["ingredients"]], foods, settings, rules)
            if assessment["reasons"]:
                raise DomainError("recipe_not_compatible", 409)
            checked.append(recipe)
        return checked, foods

    def plans(self, user_id):
        with self.db.transaction() as tx:
            home = self._member(tx, user_id)["household_id"]
            return {"items": [{**r, "data": decode(r["data"])} for r in tx.all("SELECT * FROM meal_plans WHERE user_id=? AND household_id=? ORDER BY start_date DESC LIMIT 52", (user_id, home))]}

    def _plan_time_limits(self, value, start):
        if not isinstance(value, dict) or len(value) > 7:
            raise DomainError("invalid_time_limits", 422)
        result = {}
        week = date.fromisoformat(start)
        for day, minutes in value.items():
            day = valid_date(day)
            if not day or not 0 <= (date.fromisoformat(day) - week).days < 7:
                raise DomainError("invalid_time_limits", 422)
            result[day] = None if minutes is None else integer(minutes, minimum=1, maximum=1440)
        return result

    def _plan_alternative(self, tx, user_id, home, existing, meal, meals, limits, data):
        profile = self._profile(tx, user_id)
        foods, recipes, _, versions = self._catalog(tx, user_id)
        today = self.today(profile["settings"])
        settings, rules, _, _ = self._diners(tx, user_id, meal.get("participants"), profile, versions, today)
        excluded = data.get("exclude_recipe_ids", [])
        if not isinstance(excluded, list) or len(excluded) > 100:
            raise DomainError("invalid_recipes", 422)
        excluded = {valid_uuid(r) for r in excluded} | {meal["recipe_id"]}
        limit = limits.get(meal["date"])
        candidates = [r for r in recipes if r["id"] not in excluded
                      and RECIPE_MEAL_TYPES[meal["slot"]] & set(r.get("meal_types", []))
                      and (limit is None or r["minutes"] <= limit)]
        ranked, _ = rank(candidates, foods, self._inventory(tx, home), settings, rules, today,
                         preference_mode(decode(existing["data"]).get("preference_overrides"), meal["date"], meal["slot"]),
                         meal["servings"], self.weights, staples=self._staples(tx, home))
        if not ranked:
            raise DomainError("no_compatible_recipes", 409)
        counts = Counter(m["recipe_id"] for m in meals)
        primary_counts = Counter(primary_food_id(r, foods) for r in recipes for m in meals if m["recipe_id"] == r["id"])
        ranked.sort(key=lambda item: (counts[item["recipe"]["id"]],
                                     -item["score"], primary_counts[primary_food_id(item["recipe"], foods)], item["recipe"]["id"]))
        return {"preview": True, "id": existing["id"], "version": existing["version"],
                "meal": {**meal, "recipe_id": ranked[0]["recipe"]["id"]},
                "recommendation": ranked[0]}

    def plan_action(self, user_id, data, key):
        if data.get("action") in {"generate", "preview_generate", "suggest_alternative"}:
            self.require_capability(user_id, "canUseSmartPlanning")
        home = self._household(user_id)
        with self.db.transaction(home) as tx:
            def save():
                self._member(tx, user_id, home)
                existing = tx.one("SELECT * FROM meal_plans WHERE id=? AND user_id=? AND household_id=?", (data.get("id"), user_id, home)) if data.get("id") else None
                if data.get("id") and not existing:
                    raise DomainError("plan_not_found", 404)
                if existing and existing["version"] != data.get("expected_version"):
                    raise DomainError("stale_plan", 409)
                if data.get("action") == "delete":
                    if not existing:
                        raise DomainError("plan_not_found", 404)
                    tx.execute("DELETE FROM meal_plans WHERE id=?", (existing["id"],))
                    return {"deleted": True}
                action = choice(data.get("action"), {"save", "generate", "preview_generate", "lock", "suggest_alternative", "replace", "move", "swap", "skip", "copy", "set_time_limits"})
                previous = decode(existing["data"]) if existing else {}
                start = valid_date(data.get("start_date", existing["start_date"] if existing else None))
                if not start:
                    raise DomainError("invalid_date", 422)
                limits = self._plan_time_limits(data.get("daily_limits", previous.get("daily_limits", {})), start)
                meals = data.get("meals", [])
                if action in {"lock", "suggest_alternative", "replace", "move", "swap", "skip", "copy", "set_time_limits"}:
                    if not existing:
                        raise DomainError("plan_not_found", 404)
                    meals = [dict(meal) for meal in previous.get("meals", [])]
                    if action != "set_time_limits":
                        source = next((m for m in meals if m["date"] == data.get("date") and m["slot"] == data.get("slot")), None)
                        if source is None:
                            raise DomainError("meal_not_found", 404)
                        if action == "lock":
                            if type(data.get("locked")) is not bool:
                                raise DomainError("invalid_locked", 422)
                            source["locked"] = data["locked"]
                        elif source.get("locked"):
                            raise DomainError("meal_locked", 409)
                        elif action == "suggest_alternative":
                            return self._plan_alternative(tx, user_id, home, existing, source, meals, limits, data)
                        elif action == "replace":
                            source["recipe_id"] = valid_uuid(data.get("recipe_id"))
                        elif action == "skip":
                            meals.remove(source)
                        else:
                            target_day = valid_date(data.get("target_date"))
                            target_slot = choice(data.get("target_slot"), set(PLAN_SLOTS))
                            target = next((m for m in meals if m["date"] == target_day and m["slot"] == target_slot), None)
                            if target is source:
                                raise DomainError("invalid_meal_slot", 422)
                            if target and target.get("locked"):
                                raise DomainError("meal_locked", 409)
                            if action == "swap":
                                if target is None:
                                    raise DomainError("meal_not_found", 404)
                                target["date"], target["slot"] = source["date"], source["slot"]
                            elif target is not None:
                                raise DomainError("meal_slot_occupied", 409)
                            if action == "copy":
                                meals.append({**source, "date": target_day, "slot": target_slot, "locked": False})
                            else:
                                source["date"], source["slot"] = target_day, target_slot
                if action in {"generate", "preview_generate"}:
                    profile = self._profile(tx, user_id)
                    foods, recipes, _, versions = self._catalog(tx, user_id)
                    today = self.today(profile["settings"])
                    participants = data.get("participants", [user_id])
                    settings, rules, _, _ = self._diners(tx, user_id, participants, profile, versions, today)
                    servings = integer(data.get("servings", len(participants)), minimum=1, maximum=20)
                    ranked, _ = rank(recipes, foods, self._inventory(tx, home), settings, rules, today, data.get("mode", "for_you"), servings, self.weights,
                                     staples=self._staples(tx, home))
                    if not ranked:
                        raise DomainError("no_compatible_recipes", 409)
                    for item in ranked:
                        item["component_scores"]["substantiality"] = substantiality(
                            item["recipe"], foods
                        )
                    timing = profile["settings"].get("meal_timing", {})
                    configured = timing.get("slots", {}) if isinstance(timing, dict) else {}
                    enabled_slots = [
                        slot for slot in PLAN_SLOTS if configured.get(slot, True) is True
                    ]
                    meals = weekly_meals(
                        ranked,
                        start,
                        servings,
                        participants,
                        enabled_slots,
                        foods,
                        locked=[m for m in previous.get("meals", []) if m.get("locked")],
                        daily_limits=limits,
                    )
                    if not meals:
                        raise DomainError("no_compatible_recipes", 409)
                if not isinstance(meals, list) or len(meals) > 28:
                    raise DomainError("invalid_meals", 422)
                slots = set()
                checked_recipes, _ = self._validate_meals(tx, user_id, meals)
                for meal in meals:
                    day = valid_date(meal.get("date"))
                    slot = choice(meal.get("slot"), {"breakfast", "lunch", "dinner", "snack"})
                    if not day or not 0 <= (date.fromisoformat(day) - date.fromisoformat(start)).days < 7 or (day, slot) in slots:
                        raise DomainError("invalid_meal_slot", 422)
                    slots.add((day, slot))
                if action != "lock":
                    for old in previous.get("meals", []):
                        if old.get("locked") and old not in meals:
                            raise DomainError("meal_locked", 409)
                    for meal in meals:
                        if meal.get("locked") and meal not in previous.get("meals", []):
                            raise DomainError("invalid_locked", 422)
                for meal in meals:
                    if "locked" in meal and type(meal["locked"]) is not bool:
                        raise DomainError("invalid_locked", 422)
                # Enforce time budgets on new/changed meals; retained locked meals remain intact.
                for meal, recipe in zip(meals, checked_recipes):
                    limit = limits.get(meal["date"])
                    if limit is not None and not meal.get("locked") and recipe["minutes"] > limit:
                        raise DomainError("meal_time_limit", 409)
                override_input = data.get("preference_overrides", previous.get("preference_overrides", []))
                if "preference_overrides" not in data:
                    keys = {(m["date"], m["slot"]) for m in meals}
                    override_input = [o for o in override_input if o.get("scope") == "day" or (o.get("date"), o.get("slot")) in keys]
                overrides = self._preference_overrides(override_input, start, meals)
                if data.get("action") == "preview_generate":
                    return {"preview": True, "start_date": start, "data": {**previous, "meals": meals, "preference_overrides": overrides, "daily_limits": limits}}
                identifier, stamp = existing["id"] if existing else new_id(), now()
                version = existing["version"] + 1 if existing else 1
                value = {**previous, "meals": meals, "preference_overrides": overrides, "daily_limits": limits}
                tx.execute("INSERT INTO meal_plans VALUES (?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET start_date=excluded.start_date,data=excluded.data,version=excluded.version,updated_at=excluded.updated_at", (identifier, user_id, home, start, encode(value), version, existing["created_at"] if existing else stamp, stamp))
                return {"id": identifier, "version": version, "start_date": start, "data": value}
            return self._once(tx, user_id, key, "plan", data, save)

    def _leftover_validation(self, tx, user_id, item, participants):
        profile, foods, _, _, _, today = self._context(tx, user_id)
        settings, rules, rule_versions, profiles = self._diners(tx, user_id, participants, profile, self._catalog(tx, user_id, include_recipes=False)[3], today)
        if item['user_use_date'] and item['user_use_date'] < today.isoformat():
            raise DomainError('leftover_date_passed', 409)
        original = decode(item['record'])
        ingredients = original.get('ingredients', [])
        if not ingredients:
            raise DomainError('leftover_provenance_unavailable', 409)
        food_ids = [i['food_id'] for i in ingredients]
        historical = {i['food_id']: i['food'] for i in ingredients}
        for source in (foods, historical):
            if compatibility(food_ids, source, settings, rules)['reasons']:
                raise DomainError('recipe_not_compatible', 409)
        return profile, foods, settings, rules, rule_versions, profiles, today, original

    def _remix(self, tx, user_id, item, data, servings):
        profile, foods, settings, rules, rules_version, profiles, today, original = self._leftover_validation(tx, user_id, item, data.get('participants'))
        addition = self._validate_recipe(data.get('recipe'), foods)
        needed = requirements(addition, addition['servings'])
        if compatibility(list(needed), foods, settings, rules)['reasons']:
            raise DomainError('recipe_not_compatible', 409)
        allocations, shortages = [], []
        stock = self._inventory(tx, item['household_id'])
        staples = self._staples(tx, item['household_id'])
        for food_id, amount in needed.items():
            remaining = amount
            for batch in stock:
                if batch['food_id'] != food_id or not batch_usable(batch, today):
                    continue
                used = min(remaining, batch['quantity_milli'])
                if used:
                    allocations.append({'batch_id': batch['id'], 'quantity_milli': used, 'version': batch['version']})
                    remaining -= used
            if remaining and food_id not in staples:
                shortages.append({'food_id': food_id, 'quantity': quantity(remaining)})
        original_recipe = {'servings': original['servings'], 'ingredients': [{'food_id': i['food_id'], 'quantity': i['quantity']} for i in original['ingredients'] if amount_milli(i['quantity'], zero=True)]}
        combined = requirements(original_recipe, servings)
        for food_id, amount in needed.items():
            combined[food_id] = combined.get(food_id, 0) + amount
        recipe = {**addition, 'ingredients': [{'food_id': f, 'quantity': quantity(q)} for f, q in combined.items()], 'provenance': 'leftover-remix'}
        plan = {'allocations': allocations, 'shortages': shortages, 'participant_versions': profiles, 'diet_rules_version': rules_version, 'leftover_id': item['id'], 'reused_servings': servings, 'servings': addition['servings']}
        return recipe, plan

    def leftover_action(self, user_id, data, key):
        home = self._household(user_id, write=True)
        with self.db.transaction(home) as tx:
            def change():
                self._member(tx, user_id, home, write=True)
                if data.get('action') == 'create':
                    if data.get('ingredients_confirmed') is not True:
                        raise DomainError('preparation_confirmation_required', 422)
                    recipe, foods = self._validate_meal(tx, user_id, data)
                    prepared = valid_date(data.get('prepared_at'))
                    today = self.today(self._profile(tx, user_id)['settings']).isoformat()
                    use_date = valid_date(data.get('user_use_date'))
                    if not prepared or prepared > today or (use_date and use_date < prepared):
                        raise DomainError('invalid_date', 422)
                    location = choice(data.get('location', 'fridge'), {'fridge', 'freezer'})
                    if not use_date and location == 'fridge':
                        use_date = (date.fromisoformat(prepared) + timedelta(days=3)).isoformat()
                    cooking_id, identifier, stamp = new_id(), new_id(), now()
                    servings = data['servings']
                    snapshot = {'servings': servings, 'source': 'external-preparation', 'allocations': [],
                                'ingredients': [{'food_id': f, 'quantity': quantity(q), 'food': foods[f]}
                                                for f, q in requirements(recipe, servings).items()]}
                    tx.execute('INSERT INTO cooking_sessions VALUES (?,?,?,?,?,?)', (cooking_id, user_id, home, recipe['id'], encode(snapshot), stamp))
                    tx.execute('INSERT INTO leftovers VALUES (?,?,?,?,?,?,?,?)', (identifier, home, cooking_id, servings, prepared, location, use_date, 'external-preparation'))
                    return {'id': identifier, 'remaining': servings, 'version': 1}
                identifier = valid_uuid(data.get('id'))
                item = tx.one('SELECT l.*,c.recipe_id,c.data AS record FROM leftovers l JOIN cooking_sessions c ON c.id=l.cooking_id WHERE l.id=? AND l.household_id=?', (identifier, home))
                if not item:
                    raise DomainError('leftover_not_found', 404)
                state = tx.one('SELECT * FROM leftover_state WHERE leftover_id=?', (identifier,)) or {'remaining': item['servings'], 'version': 1}
                if data.get('expected_version') != state['version']:
                    raise DomainError('stale_leftover', 409)
                action = choice(data.get('action'), {'consume', 'discard', 'move', 'date', 'transform_preview', 'transform'})
                remaining = state['remaining']
                if action in {'consume', 'discard', 'transform_preview', 'transform'}:
                    servings = integer(data.get('servings'), minimum=1, maximum=20)
                    if servings > remaining:
                        raise DomainError('insufficient_leftovers', 409)
                    if action == 'consume':
                        self._leftover_validation(tx, user_id, item, data.get('participants'))
                    if action.startswith('transform'):
                        recipe, plan = self._remix(tx, user_id, item, data, servings)
                        if action == 'transform_preview':
                            return plan
                        if data.get('preparation_confirmed') is not True:
                            raise DomainError('preparation_confirmation_required', 422)
                        if data.get('participant_versions') != plan['participant_versions'] or data.get('diet_rules_version') != plan['diet_rules_version']:
                            raise DomainError('stale_profile', 409)
                        if data.get('batch_versions') != {i['batch_id']: i['version'] for i in plan['allocations']}:
                            raise DomainError('stale_inventory', 409)
                        if plan['shortages']:
                            raise DomainError('insufficient_inventory', 409)
                        recipe_id, cooking_id, stamp = new_id(), new_id(), now()
                        tx.execute('INSERT INTO recipes VALUES (?,?)', (recipe_id, encode({**recipe, 'id': recipe_id, 'private': True, 'is_demo': False})))
                        tx.execute("INSERT INTO content_ownership VALUES ('recipe',?,?,NULL)", (recipe_id, user_id))
                        catalog = self._catalog(tx, user_id, include_recipes=False)[0]
                        plan['ingredients'] = [{'food_id': i['food_id'], 'quantity': i['quantity'], 'food': catalog[i['food_id']]} for i in recipe['ingredients']]
                        for allocation in plan['allocations']:
                            changed = tx.execute('UPDATE inventory_batches SET quantity_milli=quantity_milli-?,version=version+1,updated_at=? WHERE id=? AND version=? AND quantity_milli>=?', (allocation['quantity_milli'], stamp, allocation['batch_id'], allocation['version'], allocation['quantity_milli']))
                            if changed.rowcount != 1:
                                raise DomainError('stale_inventory', 409)
                            self._event(tx, user_id, home, allocation['batch_id'], 'leftover_remix', -allocation['quantity_milli'], {'cooking_id': cooking_id})
                        tx.execute('INSERT INTO cooking_sessions VALUES (?,?,?,?,?,?)', (cooking_id, user_id, home, recipe_id, encode(plan), stamp))
                    remaining -= servings
                    tx.execute('INSERT INTO leftover_events VALUES (?,?,?,?,?,?)', (new_id(), identifier, user_id, action, servings, now()))
                elif action == 'move':
                    tx.execute('UPDATE leftovers SET location=? WHERE id=?', (choice(data.get('location'), {'fridge', 'freezer'}), identifier))
                else:
                    tx.execute('UPDATE leftovers SET user_use_date=? WHERE id=?', (valid_date(data.get('user_use_date')), identifier))
                version = state['version'] + 1
                tx.execute('INSERT INTO leftover_state VALUES (?,?,?,?) ON CONFLICT(leftover_id) DO UPDATE SET remaining=excluded.remaining,version=excluded.version,updated_at=excluded.updated_at', (identifier, remaining, version, now()))
                return {'id': identifier, 'remaining': remaining, 'version': version}
            return self._once(tx, user_id, key, 'leftover', data, change)
