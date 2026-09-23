"""Private recipes, favorites, feedback, substitutions and product lookup."""
from collections import Counter
from html.parser import HTMLParser
import json
import re
from datetime import date, datetime, timedelta, timezone
from urllib.parse import parse_qs, urlsplit

from .auth import now
from .engine import amount_milli, batch_usable, compatibility, quantity, requirements
from .errors import DomainError
from .providers import OpenFoodFacts, barcode, https_request
from .storage import decode, encode
from .sustainability import estimate_savings
from .substitutions import CURATED_SUBSTITUTIONS, conflict_class
from .validation import choice, integer, new_id, text, valid_uuid


def _nutrition_record(food):
    """Return only source-backed canonical nutrition.

    Family averages are intentionally not used: a vegetable/meat/etc. group is
    too broad to support ingredient-level nutrition without creating false
    precision. Missing canonical values remain unavailable until curated source
    data is published.
    """
    nutrition = food.get("nutrition")
    if not nutrition or not nutrition.get("values"):
        return None
    if not nutrition.get("source_url"):
        return None
    return nutrition


class RecipeParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.recording, self.parts, self.documents, self.metadata = False, [], [], {}

    def handle_starttag(self, tag, attrs):
        values = dict(attrs)
        if tag == "script" and values.get("type", "").lower() == "application/ld+json":
            self.recording, self.parts = True, []
        if tag == "meta":
            key = (values.get("property") or values.get("name") or "").lower()
            content = values.get("content")
            if key and content and len(content) <= 20_000:
                self.metadata[key] = content

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


def _platform(url):
    parts = urlsplit(url)
    host = (parts.hostname or "").lower().removeprefix("www.")
    path = parts.path.rstrip("/")
    if parts.scheme != "https" or parts.username or parts.password or parts.port not in (None, 443):
        raise DomainError("invalid_public_url", 422)
    if host == "youtu.be" and len([item for item in path.split("/") if item]) == 1:
        return "youtube"
    if host in {"youtube.com", "m.youtube.com"}:
        if path == "/watch" and parse_qs(parts.query).get("v", [""])[0]:
            return "youtube"
        if re.match(r"^/(shorts|live)/[^/]+$", path):
            return "youtube"
    if host == "instagram.com" and re.match(r"^/(p|reel|tv)/[^/]+$", path):
        return "instagram"
    if host and "." in host:
        return "web"
    raise DomainError("unsupported_recipe_source", 422)


def _instruction_text(value):
    if isinstance(value, str):
        return [value.strip()] if value.strip() else []
    if isinstance(value, list):
        return [item for child in value for item in _instruction_text(child)]
    if isinstance(value, dict):
        if isinstance(value.get("text"), str):
            return _instruction_text(value["text"])
        return _instruction_text(value.get("itemListElement", []))
    return []


def _duration_minutes(value):
    if not isinstance(value, str):
        return None
    match = re.fullmatch(r"P(?:\d+D)?T(?:(\d+)H)?(?:(\d+)M)?", value.upper())
    if not match:
        return None
    minutes = int(match.group(1) or 0) * 60 + int(match.group(2) or 0)
    return minutes if 1 <= minutes <= 1440 else None


def _step_timer_seconds(value):
    if not isinstance(value, str):
        return None
    normalized = re.sub(r"\s+", " ", value.casefold()).strip()
    if re.search(r"\d+\s*[-–—]\s*\d+\s*(?:min|minute|minutes|minuti?|h|ore?|hours?)\b", normalized):
        return None
    minute = re.search(r"(?<!\d)(\d{1,3})\s*(?:min(?:\.|uti?|utes?)?|mins?)\b", normalized)
    if minute:
        amount = int(minute.group(1))
        return amount * 60 if 1 <= amount <= 180 else None
    hour = re.search(r"(?<!\d)(\d{1,2})(?:[.,](\d))?\s*(?:h|ora|ore|hour|hours)\b", normalized)
    if hour:
        amount = int(hour.group(1)) * 60 + int(hour.group(2) or 0) * 6
        return amount * 60 if 1 <= amount <= 180 else None
    return None


def _timed_instruction_steps(value):
    steps = []
    for instruction in _instruction_text(value):
        row = {"text": instruction}
        seconds = _step_timer_seconds(instruction)
        if seconds:
            row["timer_seconds"] = seconds
        steps.append(row)
    return steps


def _description_sections(description):
    lines = [re.sub(r"^\s*(?:[-–—•*]\s*|\d+[.)]\s*)", "", line).strip() for line in description.splitlines()]
    lines = [line for line in lines if line]
    ingredients, steps, section = [], [], None
    for line in lines:
        heading = line.casefold().rstrip(":")
        if heading in {"ingredients", "ingredienti", "you need", "what you need"}:
            section = "ingredients"
            continue
        if heading in {"method", "instructions", "steps", "procedimento", "preparazione"}:
            section = "steps"
            continue
        if section == "ingredients":
            ingredients.append(line)
        elif section == "steps":
            steps.append(line)
    return ingredients[:40], steps[:30]


def _aliases(food):
    values = {str(food.get("slug", "")).replace("-", " ")}
    values.update(str(name) for name in food.get("name", {}).values())
    expanded = set()
    for value in values:
        normalized = re.sub(r"[^a-zà-ž0-9 ]", " ", value.casefold())
        normalized = re.sub(r"\s+", " ", normalized).strip()
        if normalized:
            expanded.add(normalized)
            if normalized.endswith("s"):
                expanded.add(normalized[:-1])
    return expanded


def _map_ingredients(lines, foods):
    rows = []
    candidates = [(food, alias) for food in foods.values() for alias in _aliases(food)]
    for source in lines[:40]:
        line = re.sub(r"\s+", " ", str(source)).strip()
        normalized = re.sub(r"[^a-zà-ž0-9., ]", " ", line.casefold())
        matches = [(food, alias) for food, alias in candidates if re.search(r"(?<!\w)" + re.escape(alias) + r"(?!\w)", normalized)]
        matches.sort(key=lambda item: (-len(item[1]), item[0]["id"]))
        food = matches[0][0] if matches else None
        amount = re.match(r"^\s*(\d+(?:[.,]\d+)?)\s*(kg|g|ml|l|pcs?|pieces?|uova?|eggs?)?\b", normalized)
        quantity = None
        if food and amount:
            number = float(amount.group(1).replace(",", "."))
            unit = (amount.group(2) or "").lower()
            if food["unit"] == "g" and unit in {"g", "kg"}:
                quantity = number * (1000 if unit == "kg" else 1)
            elif food["unit"] == "ml" and unit in {"ml", "l"}:
                quantity = number * (1000 if unit == "l" else 1)
            elif food["unit"] == "pcs" and unit in {"pcs", "pc", "piece", "pieces", "uovo", "uova", "egg", "eggs"}:
                quantity = number
        if food and quantity is not None and quantity > 0:
            rendered = str(int(quantity)) if quantity.is_integer() else str(quantity).rstrip("0").rstrip(".")
            rows.append({"food_id": food["id"], "quantity": rendered, "unit": food["unit"],
                         "source_text": line, "mapping_status": "matched", "confirmed": True})
        elif food:
            rows.append({"food_id": food["id"], "quantity": None, "unit": food["unit"],
                         "source_text": line, "mapping_status": "needs_review", "confirmed": False})
        else:
            rows.append({"food_id": None, "quantity": None, "unit": None,
                         "source_text": line, "mapping_status": "unknown", "confirmed": False})
    return rows


def _compatibility_review(assessment, unmapped):
    reasons = assessment["reasons"]
    conflicts = [reason for reason in reasons if reason.get("code") != "unknown_ingredient"]
    if conflicts:
        status = "conflict"
    elif unmapped or reasons:
        status = "unknown"
    elif assessment["warnings"]:
        status = "caution"
    else:
        status = "fit"
    return {**assessment, "status": status, "unmapped_ingredients": unmapped}


def _author_name(value):
    if isinstance(value, str):
        return value[:160]
    if isinstance(value, dict):
        return str(value.get("name", ""))[:160]
    if isinstance(value, list):
        names = [_author_name(item) for item in value]
        return ", ".join(name for name in names if name)[:160]
    return ""


class ContentService:
    def recipes(self, user_id):
        with self.db.transaction() as tx:
            self._member(tx, user_id)
            _, recipes, _, _ = self._catalog(tx, user_id)
            recipes = [recipe for recipe in recipes if recipe.get("recommendation_eligible") is not False]
            favorites = {r["recipe_id"] for r in tx.all("SELECT recipe_id FROM recipe_favorites WHERE user_id=?", (user_id,))}
            return {"items": [{**r, "favorite": r["id"] in favorites} for r in recipes]}

    def recipe_action(self, user_id, data, key):
        with self.db.transaction() as tx:
            profile, foods, recipes, rules, _, _ = self._context(tx, user_id)
            def save():
                action = data.get("action")
                recipe_id = data.get("recipe_id")
                recipe = next((r for r in recipes if r["id"] == recipe_id), None)
                if action in {"favorite", "feedback", "substitute", "substitution_candidates", "delete"} and not recipe:
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
                        tx.execute("UPDATE recipes SET data=? WHERE id=?", (encode({**recipe, "archived": True}), recipe_id))
                        return {"archived": True}
                    tx.execute("DELETE FROM content_ownership WHERE kind='recipe' AND content_id=?", (recipe_id,))
                    tx.execute("DELETE FROM recipes WHERE id=?", (recipe_id,))
                    return {"deleted": True}
                if action == "substitution_candidates":
                    original_id = valid_uuid(data.get("food_id"))
                    original = foods.get(original_id)
                    if not original or original_id not in {i["food_id"] for i in recipe["ingredients"]}:
                        raise DomainError("invalid_substitution", 422)
                    home = self._household(user_id)
                    inventory = self._inventory(tx, home)
                    available = {}
                    for batch in inventory:
                        if batch_usable(batch, self.today(profile["settings"])):
                            canonical_id = batch.get("canonical_food_id") or batch["food_id"]
                            available[canonical_id] = available.get(canonical_id, 0) + batch["quantity_milli"]
                    by_slug = {food.get("slug"): food for food in foods.values() if food.get("slug")}
                    candidates, seen = [], set()

                    def add_candidate(food, role, source):
                        if (
                            not food
                            or food["id"] == original_id
                            or food["id"] in seen
                            or food.get("group") == "packaged"
                            or food.get("ingredient_status") != "known"
                            or compatibility([food["id"]], foods, profile["settings"], rules)["reasons"]
                        ):
                            return
                        seen.add(food["id"])
                        candidates.append({
                            "food": food,
                            "role": role,
                            "source": source,
                            "at_home": available.get(food["id"], 0) > 0,
                            "available": quantity(available.get(food["id"], 0)),
                        })

                    for candidate in CURATED_SUBSTITUTIONS.get(original.get("slug"), []):
                        add_candidate(by_slug.get(candidate["slug"]), candidate["role"], "curated")
                    peers = sorted(
                        (
                            food
                            for food in foods.values()
                            if food.get("group") == original.get("group")
                            and food.get("unit") == original.get("unit")
                        ),
                        key=lambda food: (0 if available.get(food["id"], 0) > 0 else 1, food.get("slug", food["id"])),
                    )
                    for food in peers:
                        add_candidate(food, "same_food_family", "family")
                        if len(candidates) >= 8:
                            break
                    return {"original": original, "candidates": candidates[:8]}
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
                if assessment["reasons"] and data.get("safety_acknowledged") is not True:
                    raise DomainError("recipe_not_compatible", 409, assessment)
                identifier = new_id()
                value.update(id=identifier, is_demo=False, private=True,
                             safety_acknowledged=bool(assessment["reasons"]),
                             imported_assessment=assessment if value.get("source_url") else None)
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
            normalized[lang] = []
            for step in items:
                if isinstance(step, dict):
                    row = {"text": text(step.get("text"), maximum=2000)}
                    timer_seconds = step.get("timer_seconds")
                    if timer_seconds is not None:
                        if type(timer_seconds) is not int or not 1 <= timer_seconds <= 10_800:
                            raise DomainError("invalid_recipe_steps", 422)
                        row["timer_seconds"] = timer_seconds
                    normalized[lang].append(row)
                else:
                    normalized[lang].append(text(step, maximum=2000))
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
        source_url = text(value.get("source_url", ""), maximum=2000, empty=True)
        source_platform = text(value.get("source_platform", ""), maximum=30, empty=True)
        thumbnail = text(value.get("source_thumbnail_url", ""), maximum=2000, empty=True)
        source_title = text(value.get("source_title", ""), maximum=160, empty=True)
        source_creator = text(value.get("source_creator", ""), maximum=160, empty=True)
        imported_at = text(value.get("imported_at", ""), maximum=40, empty=True)
        if any(url and urlsplit(url).scheme != "https" for url in (source_url, thumbnail)):
            raise DomainError("invalid_public_url", 422)
        adaptations = value.get("adaptations", [])
        if not isinstance(adaptations, list) or len(adaptations) > 40:
            raise DomainError("invalid_recipe", 422)
        adaptations = [{"from_food_id": valid_uuid(item.get("from_food_id")),
                        "to_food_id": valid_uuid(item.get("to_food_id")),
                        "role": text(item.get("role", ""), maximum=60, empty=True)}
                       for item in adaptations if isinstance(item, dict)]
        return {"title": title, "steps": normalized, "ingredients": items, "servings": integer(value.get("servings"), minimum=1, maximum=20), "minutes": integer(value.get("minutes"), minimum=1, maximum=1440), "cuisine": text(value.get("cuisine", "other"), maximum=60), "difficulty": choice(value.get("difficulty", "beginner"), {"beginner", "confident", "advanced"}), "provenance": text(value.get("provenance", "user-import"), maximum=60), "source_url": source_url, "source_platform": source_platform, "source_thumbnail_url": thumbnail, "source_title": source_title, "source_creator": source_creator, "imported_at": imported_at, "adaptations": adaptations, "nutrition": None}

    def import_url(self, user_id, data):
        self.check_allowance(user_id, 'smart_import')
        if data.get("private_use_confirmed") is not True:
            raise DomainError("private_use_confirmation_required", 422)
        url = text(data.get("url"), maximum=2000)
        platform = _platform(url)
        parser = RecipeParser()
        document = https_request(url).decode("utf-8", errors="replace")
        parser.feed(document)
        recipe = find_recipe(parser.documents)
        description = parser.metadata.get("og:description") or parser.metadata.get("description") or ""
        if not recipe and not description:
            raise DomainError("source_private_or_unavailable", 422)
        ingredients_text = recipe.get("recipeIngredient", []) if recipe else []
        description_ingredients, description_steps = _description_sections(description)
        ingredients_text = ingredients_text or description_ingredients
        instruction_source = recipe.get("recipeInstructions", []) if recipe else description_steps
        instructions = _instruction_text(instruction_source)
        timed_steps = _timed_instruction_steps(instruction_source)
        if not ingredients_text and not instructions:
            raise DomainError("recipe_metadata_not_found", 422)
        with self.db.transaction() as tx:
            self._member(tx, user_id)
            foods, _, _, _ = self._catalog(tx, user_id)
            ingredient_rows = _map_ingredients(ingredients_text, foods)
        title = (recipe.get("name") if recipe else parser.metadata.get("og:title")) or ""
        title = re.sub(r"\s*[-|]\s*(YouTube|Instagram)\s*$", "", str(title), flags=re.I)[:160]
        servings_match = re.search(r"\d+", str(recipe.get("recipeYield", ""))) if recipe else None
        prep_minutes = _duration_minutes(recipe.get("prepTime")) if recipe else None
        cook_minutes = _duration_minutes(recipe.get("cookTime")) if recipe else None
        total_minutes = _duration_minutes(recipe.get("totalTime")) if recipe else None
        minutes = total_minutes or (
            prep_minutes + cook_minutes
            if prep_minutes is not None and cook_minutes is not None
            else prep_minutes or cook_minutes
        )
        thumbnail = parser.metadata.get("og:image", "")
        result = {
            "title": title,
            "ingredients_text": [str(item)[:500] for item in ingredients_text[:40]],
            "ingredient_rows": ingredient_rows,
            "steps": instructions,
            "timed_steps": timed_steps,
            "servings": int(servings_match.group()) if servings_match and 1 <= int(servings_match.group()) <= 20 else None,
            "prep_minutes": prep_minutes,
            "cook_minutes": cook_minutes,
            "total_minutes": total_minutes or minutes,
            "minutes": minutes,
            "source_url": url,
            "source_platform": platform,
            "source_thumbnail_url": thumbnail if thumbnail.startswith("https://") else "",
            "source_title": title,
            "source_creator": _author_name(recipe.get("author")) if recipe else "",
            "imported_at": now(),
            "provenance": "public-recipe-link",
            "requires_mapping": any(row["mapping_status"] != "matched" for row in ingredient_rows),
            "missing_fields": [field for field, value in (("title", title), ("ingredients", ingredients_text), ("steps", instructions), ("servings", servings_match), ("minutes", minutes)) if not value],
        }
        self.consume_allowance(user_id, 'smart_import')
        return result

    def import_review(self, user_id, data):
        home = self._household(user_id)
        rows = data.get("ingredient_rows")
        if not isinstance(rows, list) or not 1 <= len(rows) <= 40:
            raise DomainError("invalid_ingredients", 422)
        with self.db.transaction() as tx:
            profile, foods, _, rules, versions, today = self._context(tx, user_id)
            inventory = self._inventory(tx, home)
            diets = {row["id"]: decode(row["data"]) for row in tx.all("SELECT id,data FROM diet_definitions")}
            recognized, normalized, unresolved = [], [], []
            for index, row in enumerate(rows):
                if not isinstance(row, dict):
                    raise DomainError("invalid_ingredients", 422)
                food = foods.get(row.get("food_id"))
                status = row.get("mapping_status", "unknown")
                if status not in {"matched", "needs_review", "unknown"}:
                    raise DomainError("invalid_ingredients", 422)
                try:
                    amount = amount_milli(row.get("quantity")) if food else None
                    if food and food["unit"] == "pcs" and amount % 1000:
                        raise DomainError("whole_units_required", 422)
                except DomainError:
                    amount = None
                confirmed = row.get("confirmed") is True and status == "matched"
                if food and confirmed:
                    recognized.append(food["id"])
                if food and amount and confirmed:
                    normalized.append({"index": index, "food_id": food["id"], "quantity_milli": amount})
                else:
                    unresolved.append({"index": index, "food_id": food["id"] if food else None,
                                       "source_text": str(row.get("source_text", ""))[:500],
                                       "code": "ingredient_mapping_incomplete"})
            assessment = compatibility(recognized, foods, profile["settings"], rules)
            review = _compatibility_review(assessment, unresolved)
            classified = []
            for reason in assessment["reasons"]:
                diet = diets.get(reason.get("diet_id"), {})
                classified.append({**reason, "classification": conflict_class(reason["code"], medical=bool(diet.get("medical")))})

            available_by_food = {}
            soon = set()
            for batch in inventory:
                if not batch_usable(batch, today):
                    continue
                available_by_food[batch["food_id"]] = available_by_food.get(batch["food_id"], 0) + batch["quantity_milli"]
                if batch["expiry_date"] and 0 <= (date.fromisoformat(batch["expiry_date"]) - today).days <= 2:
                    soon.add(batch["food_id"])
            availability = []
            for item in normalized:
                available = available_by_food.get(item["food_id"], 0)
                availability.append({"index": item["index"], "food_id": item["food_id"],
                                     "required": quantity(item["quantity_milli"]),
                                     "available": quantity(min(available, item["quantity_milli"])),
                                     "at_home": available >= item["quantity_milli"],
                                     "use_soon": item["food_id"] in soon})

            suggestions = []
            by_slug = {food.get("slug"): food for food in foods.values()}
            conflicting_ids = sorted({reason.get("food_id") for reason in assessment["reasons"] if reason.get("food_id")})
            for food_id in conflicting_ids:
                original = foods.get(food_id)
                candidates = []
                for candidate in CURATED_SUBSTITUTIONS.get(original.get("slug") if original else None, []):
                    replacement = by_slug.get(candidate["slug"])
                    if not replacement or compatibility([replacement["id"]], foods, profile["settings"], rules)["reasons"]:
                        continue
                    candidates.append({"food": replacement, "role": candidate["role"],
                                       "review": candidate["review"],
                                       "at_home": available_by_food.get(replacement["id"], 0) > 0,
                                       "available": quantity(available_by_food.get(replacement["id"], 0))})
                suggestions.append({"food_id": food_id, "candidates": candidates})

            active_diets = []
            for selected in profile["settings"].get("diets", []):
                diet = diets.get(selected.get("diet_id"), {})
                if diet:
                    active_diets.append({key: diet.get(key) for key in ("id", "slug", "name", "medical")})

            return {"compatibility": {**review, "classified_reasons": classified},
                    "inventory": {"available_count": sum(item["at_home"] for item in availability),
                                  "total_count": len(rows), "items": availability,
                                  "missing_food_ids": [item["food_id"] for item in availability if not item["at_home"]],
                                  "use_soon_food_ids": sorted({item["food_id"] for item in availability if item["use_soon"]}),
                                  "unresolved_count": len(unresolved)},
                    "substitutions": suggestions, "active_diets": active_diets,
                    "diet_rules_version": versions}

    def product(self, user_id, code):
        if not self.feature_enabled('barcode_scan'):
            raise DomainError('product_provider_not_configured', 503)
        self._household(user_id)
        code = barcode(code)
        with self.db.transaction() as tx:
            existing = tx.one("SELECT * FROM food_products WHERE barcode=?", (code,))
            if existing and existing["updated_at"] > (datetime.now(timezone.utc) - timedelta(days=7)).isoformat():
                return {**decode(existing["data"]), "id": existing["id"], "mapped_food_id": existing["food_id"]}
        value = (getattr(self, "product_provider", None) or OpenFoodFacts()).lookup(code)
        with self.db.transaction() as tx:
            identifier = existing["id"] if existing else new_id()
            tx.execute("INSERT INTO food_products VALUES (?,?,NULL,?,1,?) ON CONFLICT(barcode) DO UPDATE SET data=excluded.data,updated_at=excluded.updated_at,version=food_products.version+1", (identifier, code, encode(value), now()))
            mapped = existing["food_id"] if existing else None
            return {**value, "id": identifier, "mapped_food_id": mapped}

    def insights(self, user_id):
        home = self._household(user_id)
        with self.db.transaction() as tx:
            rows = tx.all("SELECT kind,delta_milli,created_at FROM inventory_events WHERE household_id=? ORDER BY created_at DESC LIMIT 2000", (home,))
            counts = Counter(r["kind"] for r in rows)
            sessions = tx.all("SELECT recipe_id,data FROM cooking_sessions WHERE user_id=? ORDER BY created_at DESC LIMIT 100", (user_id,))
            sessions = [row for row in sessions if decode(row['data']).get('source') != 'external-preparation']
            amounts = tx.all("SELECT e.batch_id,e.kind,e.delta_milli,e.created_at,b.expiry_date,b.expiry_kind,f.data AS food_data,m.data AS metadata,(SELECT c.delta_milli FROM inventory_events c WHERE c.batch_id=e.batch_id AND c.kind IN ('created','scan_confirmed') ORDER BY c.created_at,c.id LIMIT 1) AS initial_milli FROM inventory_events e JOIN inventory_batches b ON b.id=e.batch_id JOIN foods f ON f.id=b.food_id LEFT JOIN inventory_metadata m ON m.batch_id=b.id WHERE e.household_id=? AND e.kind IN ('consumed','discarded','cooked') ORDER BY e.created_at DESC LIMIT 2000", (home,))
            recorded = {}
            for row in amounts:
                unit = decode(row['food_data'])['unit']
                kind = 'discarded' if row['kind'] == 'discarded' else 'used'
                recorded.setdefault(unit, {'used': 0, 'discarded': 0})[kind] += abs(row['delta_milli'])
            recorded = {unit: {kind: quantity(value) for kind, value in values.items()} for unit, values in recorded.items()}
            savings = estimate_savings([row for row in amounts if row["kind"] in {"consumed", "cooked"}])
            return {"recorded_quantities": recorded, "inventory_event_counts": dict(counts), "cooked_meals": len(sessions), "different_recipes": len({r["recipe_id"] for r in sessions}), "window": "latest_2000_events_and_100_meals", **savings}

    def recipe_nutrition(self, recipe, foods, servings):
        from decimal import Decimal, InvalidOperation
        totals, missing, sources, coverage, units, conversions = {}, [], {}, {}, {}, {}
        estimated_food_ids = []
        needed = requirements(recipe, servings)

        def positive(value):
            try:
                parsed = Decimal(str(value))
            except (InvalidOperation, TypeError, ValueError):
                return None
            return parsed if parsed.is_finite() and parsed > 0 else None

        for food_id, amount in needed.items():
            food = foods[food_id]
            nutrients = _nutrition_record(food)
            if not nutrients:
                missing.append(food_id)
                continue

            basis = nutrients.get("basis")
            unit = food["unit"]
            basis_amount = None
            conversion = "direct"

            if unit == "g" and basis == "100g":
                basis_amount = Decimal(amount)
            elif unit == "ml" and basis == "100ml":
                basis_amount = Decimal(amount)
            elif unit == "ml" and basis == "100g":
                density = positive(nutrients.get("density_g_per_ml"))
                if density is not None:
                    basis_amount = Decimal(amount) * density
                    conversion = "density_g_per_ml"
            elif unit == "g" and basis == "100ml":
                density = positive(nutrients.get("density_g_per_ml"))
                if density is not None:
                    basis_amount = Decimal(amount) / density
                    conversion = "density_g_per_ml"
            elif unit == "pcs" and basis == "100g":
                grams = positive(nutrients.get("grams_per_piece"))
                if grams is not None:
                    # Recipe quantities are stored in milli-pieces; multiplying
                    # by grams/piece produces milli-grams.
                    basis_amount = Decimal(amount) * grams
                    conversion = "grams_per_piece"
            elif unit == "pcs" and basis == "1pcs":
                basis_amount = Decimal(amount)
                conversion = "per_piece"

            if basis_amount is None:
                missing.append(food_id)
                continue

            sources[food_id] = nutrients["source_url"]
            conversions[food_id] = conversion
            if nutrients.get("estimated") is True:
                estimated_food_ids.append(food_id)
            divisor = Decimal(1000) if basis == "1pcs" else Decimal(100000)
            for name, value in nutrients["values"].items():
                if name in units and units[name] != value["unit"]:
                    raise DomainError("inconsistent_nutrition_units", 409)
                units[name] = value["unit"]
                totals[name] = (
                    totals.get(name, Decimal(0))
                    + Decimal(str(value["value"])) * basis_amount / divisor
                )
                coverage[name] = coverage.get(name, 0) + 1

        return {
            "totals": {
                name: {
                    "value": str(total.quantize(Decimal("0.01"))),
                    "unit": units[name],
                    "complete": coverage[name] == len(needed),
                }
                for name, total in totals.items()
            },
            "servings": servings,
            "complete": bool(totals)
            and not missing
            and all(count == len(needed) for count in coverage.values()),
            "missing_food_ids": missing,
            "estimated_food_ids": estimated_food_ids,
            "estimated": bool(estimated_food_ids),
            "sources": sources,
            "basis_conversions": conversions,
            "method": "source_backed_ingredient_amounts_no_cooking_retention_adjustment",
        }

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
                foods = self._catalog(tx, user_id)[0]
                selected_food_id = data.get('food_id') or row['food_id']
                canonical = foods.get(valid_uuid(selected_food_id)) if selected_food_id else None
                if not canonical or canonical.get('group') == 'packaged':
                    raise DomainError('product_family_required', 422)
                amount = amount_milli(data.get('quantity'))
                if amount % 1000:
                    raise DomainError('whole_units_required', 422)
                from .catalog import identifier
                food_id = identifier('product-food', row['barcode'])
                food = {'id': food_id, 'name': {'en': product['name'], 'it': product['name']}, 'group': 'packaged', 'unit': 'pcs', 'ingredient_status': 'unknown', 'allergens': [], 'may_contain': [], 'intolerances': [], 'nutrition': product.get('nutrition'), 'provenance': 'openfoodfacts-unreviewed', 'is_demo': False}
                # The shared package entity remains deliberately unclassified for
                # safety. The user-selected canonical food and family are stored
                # on this inventory batch only, so one household cannot change
                # another household's semantic classification.
                tx.execute('INSERT INTO foods VALUES (?,?) ON CONFLICT(id) DO UPDATE SET data=excluded.data', (food_id, encode(food)))
                batch_id, stamp = new_id(), now()
                tx.execute('INSERT INTO inventory_batches VALUES (?,?,?,?,?,?,?,?,?,?,?,?)', (batch_id, home, food_id, amount, 'fridge', None, 'unknown', None, 'barcode-confirmed', 1, stamp, stamp))
                tx.execute('INSERT INTO inventory_metadata VALUES (?,?,?)', (batch_id, encode({'barcode': row['barcode'], 'product_id': row['id'], 'canonical_food_id': canonical['id'], 'food_group': canonical['group'], 'lot': text(data.get('lot', ''), maximum=100, empty=True), 'ingredients_unreviewed': True}), stamp))
                self._event(tx, user_id, home, batch_id, 'created', amount)
                duplicates = tx.one('SELECT COUNT(*) AS n FROM inventory_batches WHERE household_id=? AND food_id=? AND quantity_milli>0', (home, food_id))['n'] - 1
                return {'id': batch_id, 'version': 1, 'existing_batches': duplicates, 'assessment': 'unknown_ingredients', 'food_group': canonical['group'], 'canonical_food_id': canonical['id']}
            return self._once(tx, user_id, key, 'product_stock', data, save)
