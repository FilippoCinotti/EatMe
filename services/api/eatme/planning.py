"""Transactional shopping, weekly plans, and leftover lifecycle."""
from datetime import date, timedelta

from .auth import now
from .engine import amount_milli, batch_usable, compatibility, quantity, rank, requirements
from .errors import DomainError
from .storage import decode, encode
from .validation import choice, integer, new_id, text, valid_date, valid_uuid


class PlanningService:
    def shopping(self, user_id):
        with self.db.transaction() as tx:
            home = self._member(tx, user_id)["household_id"]
            return {"items": [{**r, "quantity": quantity(r["quantity_milli"]), "checked": bool(r["checked"])} for r in tx.all("SELECT * FROM shopping_items WHERE household_id=? ORDER BY checked,category,label,id", (home,))]}

    def shopping_action(self, user_id, data, key):
        home = self._household(user_id, write=True)
        with self.db.transaction(home) as tx:
            def change():
                self._member(tx, user_id, home, write=True)
                action = data.get("action")
                if action == "add":
                    food_id = data.get("food_id")
                    food = tx.one("SELECT data FROM foods WHERE id=?", (food_id,)) if food_id else None
                    if food_id and not food:
                        raise DomainError("food_not_found", 404)
                    food = decode(food["data"]) if food else None
                    unit = food["unit"] if food else choice(data.get("unit", "pcs"), {"pcs", "g", "ml"})
                    label = text(data.get("label") or (food["name"]["en"] if food else None), maximum=120)
                    amount = amount_milli(data.get("quantity"))
                    if unit == "pcs" and amount % 1000:
                        raise DomainError("whole_units_required", 422)
                    identifier = self._shopping_insert(tx, user_id, home, food_id, label, amount, unit, text(data.get("category", "other"), maximum=40), "manual")
                    return {"id": identifier, "version": 1}
                if action == "generate":
                    meals = data.get("meals")
                    source = "recipes"
                    if data.get("plan_id"):
                        plan = tx.one("SELECT * FROM meal_plans WHERE id=? AND user_id=? AND household_id=?", (valid_uuid(data["plan_id"]), user_id, home))
                        if not plan:
                            raise DomainError("plan_not_found", 404)
                        meals, source = decode(plan["data"])["meals"], "plan:" + plan["id"]
                    if not isinstance(meals, list) or not 1 <= len(meals) <= 28:
                        raise DomainError("invalid_meals", 422)
                    totals, foods = {}, {}
                    for meal in meals:
                        checked, catalog = self._validate_meal(tx, user_id, meal)
                        foods.update(catalog)
                        for food_id, amount in requirements(checked, meal["servings"]).items():
                            totals[food_id] = totals.get(food_id, 0) + amount
                    today = self.today(self._profile(tx, user_id)["settings"])
                    for batch in self._inventory(tx, home):
                        if batch_usable(batch, today) and batch["food_id"] in totals:
                            totals[batch["food_id"]] = max(0, totals[batch["food_id"]] - batch["quantity_milli"])
                    # Replace only this plan's generated lines; manual lines remain explicit purchases.
                    tx.execute("DELETE FROM shopping_items WHERE household_id=? AND source_key=?", (home, source))
                    identifiers = []
                    for food_id, amount in totals.items():
                        if amount:
                            food = foods[food_id]
                            identifiers.append(self._shopping_insert(tx, user_id, home, food_id, food["name"]["en"], amount, food["unit"], food.get("group", "other"), source))
                    return {"ids": identifiers}
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
                    batch_id, stamp = new_id(), now()
                    tx.execute("INSERT INTO inventory_batches VALUES (?,?,?,?,?,?,?,?,?,?,?,?)", (batch_id, home, item["food_id"], item["quantity_milli"], location, expiry, kind, None, "shopping", 1, stamp, stamp))
                    self._event(tx, user_id, home, batch_id, "purchased", item["quantity_milli"])
                    tx.execute("DELETE FROM shopping_items WHERE id=?", (identifier,))
                    return {"batch_id": batch_id, "purchased": True}
                if action == "check":
                    if type(data.get("checked")) is not bool:
                        raise DomainError("invalid_checked", 422)
                    tx.execute("UPDATE shopping_items SET checked=?,version=version+1,updated_at=? WHERE id=?", (int(data["checked"]), now(), identifier))
                elif action == "edit":
                    amount = amount_milli(data.get("quantity"))
                    if item["unit"] == "pcs" and amount % 1000:
                        raise DomainError("whole_units_required", 422)
                    tx.execute("UPDATE shopping_items SET label=?,quantity_milli=?,version=version+1,updated_at=? WHERE id=?", (text(data.get("label", item["label"]), maximum=120), amount, now(), identifier))
                else:
                    raise DomainError("invalid_action", 422)
                return {"id": identifier, "version": item["version"] + 1}
            return self._once(tx, user_id, key, "shopping", data, change)

    def _shopping_insert(self, tx, user_id, home, food_id, label, amount, unit, category, source):
        identifier, stamp = new_id(), now()
        tx.execute("INSERT INTO shopping_items VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)", (identifier, home, food_id, label, amount, unit, category, 0, source, 1, user_id, stamp, stamp))
        return identifier

    def _validate_meal(self, tx, user_id, meal):
        if not isinstance(meal, dict):
            raise DomainError("invalid_meal", 422)
        integer(meal.get("servings"), minimum=1, maximum=20)
        profile, foods, recipes, _, _, today = self._context(tx, user_id)
        versions = self._catalog(tx, user_id)[3]
        settings, rules, _, _ = self._diners(tx, user_id, meal.get("participants"), profile, versions, today)
        recipe = next((r for r in recipes if r["id"] == meal.get("recipe_id")), None)
        if not recipe:
            raise DomainError("recipe_not_found", 404)
        assessment = compatibility([i["food_id"] for i in recipe["ingredients"]], foods, settings, rules)
        if assessment["reasons"]:
            # Do not expose another participant's allergies through the rejection payload.
            raise DomainError("recipe_not_compatible", 409)
        return recipe, foods

    def plans(self, user_id):
        with self.db.transaction() as tx:
            home = self._member(tx, user_id)["household_id"]
            return {"items": [{**r, "data": decode(r["data"])} for r in tx.all("SELECT * FROM meal_plans WHERE user_id=? AND household_id=? ORDER BY start_date DESC LIMIT 52", (user_id, home))]}

    def plan_action(self, user_id, data, key):
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
                start = valid_date(data.get("start_date"))
                if not start:
                    raise DomainError("invalid_date", 422)
                meals = data.get("meals", [])
                if data.get("action") == "generate":
                    profile, foods, recipes, _, _, today = self._context(tx, user_id)
                    participants = data.get("participants", [user_id])
                    settings, rules, _, _ = self._diners(tx, user_id, participants, profile, self._catalog(tx, user_id)[3], today)
                    servings = integer(data.get("servings", len(participants)), minimum=1, maximum=20)
                    ranked, _ = rank(recipes, foods, self._inventory(tx, home), settings, rules, today, data.get("mode", "for_you"), servings, self.weights)
                    if not ranked:
                        raise DomainError("no_compatible_recipes", 409)
                    meals = [{"date": (date.fromisoformat(start) + timedelta(days=i)).isoformat(), "slot": "dinner", "recipe_id": ranked[i % len(ranked)]["recipe"]["id"], "servings": servings, "participants": participants} for i in range(7)]
                if not isinstance(meals, list) or len(meals) > 28:
                    raise DomainError("invalid_meals", 422)
                slots = set()
                for meal in meals:
                    self._validate_meal(tx, user_id, meal)
                    day = valid_date(meal.get("date"))
                    slot = choice(meal.get("slot"), {"breakfast", "lunch", "dinner", "snack"})
                    if not day or not 0 <= (date.fromisoformat(day) - date.fromisoformat(start)).days < 7 or (day, slot) in slots:
                        raise DomainError("invalid_meal_slot", 422)
                    slots.add((day, slot))
                identifier, stamp = existing["id"] if existing else new_id(), now()
                version = existing["version"] + 1 if existing else 1
                value = {"meals": meals}
                tx.execute("INSERT INTO meal_plans VALUES (?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET start_date=excluded.start_date,data=excluded.data,version=excluded.version,updated_at=excluded.updated_at", (identifier, user_id, home, start, encode(value), version, existing["created_at"] if existing else stamp, stamp))
                return {"id": identifier, "version": version, "start_date": start, "data": value}
            return self._once(tx, user_id, key, "plan", data, save)

    def _leftover_validation(self, tx, user_id, item, participants):
        profile, foods, _, _, _, today = self._context(tx, user_id)
        settings, rules, rule_versions, profiles = self._diners(tx, user_id, participants, profile, self._catalog(tx, user_id)[3], today)
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
        for food_id, amount in needed.items():
            remaining = amount
            for batch in stock:
                if batch['food_id'] != food_id or not batch_usable(batch, today):
                    continue
                used = min(remaining, batch['quantity_milli'])
                if used:
                    allocations.append({'batch_id': batch['id'], 'quantity_milli': used, 'version': batch['version']})
                    remaining -= used
            if remaining:
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
                        tx.execute('INSERT INTO recipes VALUES (?,?)', (recipe_id, encode({**recipe, 'id': recipe_id})))
                        tx.execute("INSERT INTO content_ownership VALUES ('recipe',?,?,NULL)", (recipe_id, user_id))
                        catalog = self._catalog(tx, user_id)[0]
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
