from __future__ import annotations

from datetime import date
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP

from .errors import DomainError


def amount_milli(value, *, zero: bool = False) -> int:
    if isinstance(value, bool):
        raise DomainError("invalid_quantity", 422)
    try:
        amount = Decimal(str(value))
        if not amount.is_finite() or amount < 0 or (not zero and amount == 0) or amount > 1_000_000:
            raise InvalidOperation
        scaled = amount * 1000
        if scaled != scaled.to_integral_value():
            raise InvalidOperation
        return int(scaled)
    except (InvalidOperation, ValueError, TypeError):
        raise DomainError("invalid_quantity",422) from None


def quantity(value: int) -> str:
    return format(Decimal(value)/1000, "f").rstrip("0").rstrip(".") if value % 1000 else str(value//1000)


def requirements(recipe: dict, servings: int) -> dict[str,int]:
    if type(servings) is not int or not 1 <= servings <= 20:
        raise DomainError("invalid_servings",422)
    needed: dict[str,int] = {}
    for ingredient in recipe["ingredients"]:
        amount = (Decimal(amount_milli(ingredient["quantity"])) * servings / recipe["servings"]).quantize(Decimal(1),rounding=ROUND_HALF_UP)
        key = ingredient["food_id"]
        needed[key] = needed.get(key,0)+int(amount)
    return needed


def batch_usable(batch: dict, today: date) -> bool:
    # A best-before or estimated date is never interpreted as a safety date.
    return not batch.get("recalls") and not (batch["expiry_kind"] == "use_by" and batch["expiry_date"] and date.fromisoformat(batch["expiry_date"]) < today)


def active_rules(assignments: list[dict], versions: list[dict], today: date) -> tuple[list[dict],dict]:
    rules, selected = [], {}
    for assignment in assignments:
        matching = [v for v in versions if v["diet_id"] == assignment["diet_id"] and v["status"] == "PUBLISHED"
                    and date.fromisoformat(v["effective_from"]) <= today
                    and (not v["effective_until"] or today < date.fromisoformat(v["effective_until"]))]
        if not matching:
            raise DomainError("diet_rules_unavailable",409,{"diet_id":assignment["diet_id"]})
        version = max(matching,key=lambda v:v["version"])
        selected[assignment["diet_id"]] = version["version"]
        for rule in version["rules"]:
            rules.append({**rule,"strictness":assignment["strictness"],"diet_id":assignment["diet_id"]})
    return rules, selected


def compatibility(food_ids: list[str], foods: dict, profile: dict, rules: list[dict]) -> dict:
    reasons, warnings, preferences = [], [], 0
    for food_id in sorted(set(food_ids)):
        food = foods.get(food_id)
        if not food or food.get("ingredient_status") != "known":
            reasons.append({"code":"unknown_ingredient","food_id":food_id})
            continue
        for allergen in sorted(set(food.get("allergens",[])) & set(profile["allergies"])):
            reasons.append({"code":"contains_allergen","food_id":food_id,"allergen":allergen})
        for allergen in sorted(set(food.get("may_contain",[])) & set(profile["allergies"])):
            reasons.append({"code":"may_contain_allergen","food_id":food_id,"allergen":allergen})
        for intolerance in sorted(set(food.get("intolerances",[])) & set(profile["intolerances"])):
            reasons.append({"code":"intolerance_conflict","food_id":food_id,"intolerance":intolerance})
        if food_id in profile.get("never_suggest",[]):
            reasons.append({"code":"never_suggest","food_id":food_id})
        for rule in rules:
            matched = food["group"] in rule.get("groups",[]) or food_id in rule.get("food_ids",[])
            if rule["type"] == "EXCLUDE" and matched:
                item = {"code":"diet_exclusion","food_id":food_id,"diet_id":rule["diet_id"]}
                if rule.get("hard_constraint") or rule["strictness"] != "flexible":
                    reasons.append(item)
                else:
                    warnings.append(item)
            elif rule["type"] == "PREFER" and matched:
                preferences += 1
            elif rule["type"] not in {"EXCLUDE","PREFER","ALLOW"}:
                # Unsupported scientific/nutrient operators fail closed. Never ignore a rule.
                reasons.append({"code":"rule_not_evaluable","diet_id":rule["diet_id"]})
    return {"status":"not_compatible" if reasons else "no_known_conflict", "reasons":reasons,
            "warnings":warnings, "preference_matches":preferences,
            "notice":"demo_data_not_a_safety_guarantee"}


DEFAULT_WEIGHTS = {
    "for_you":{"availability":0.45,"expiry":0.25,"diet":0.20,"speed":0.10},
    "use_soon":{"availability":0.25,"expiry":0.60,"diet":0.10,"speed":0.05},
    "no_shopping":{"availability":0.70,"expiry":0.15,"diet":0.10,"speed":0.05},
    "quick":{"availability":0.30,"expiry":0.15,"diet":0.10,"speed":0.45},
    "health_first":{"availability":0.25,"expiry":0.15,"diet":0.55,"speed":0.05},
}


def rank(recipes: list[dict], foods: dict, inventory: list[dict], profile: dict, rules: list[dict],
         today: date, mode: str, servings: int, weights: dict | None = None) -> tuple[list[dict],list[dict]]:
    profiles = weights if weights is not None else DEFAULT_WEIGHTS
    weight_mode = "for_you" if mode == "plant_based" else mode
    if weight_mode not in profiles:
        raise DomainError("unknown_mode",422)
    available: dict[str,int] = {}
    soon = set()
    for batch in inventory:
        if not batch_usable(batch,today) or not batch["quantity_milli"]:
            continue
        available[batch["food_id"]] = available.get(batch["food_id"],0)+batch["quantity_milli"]
        if batch["expiry_date"] and 0 <= (date.fromisoformat(batch["expiry_date"])-today).days <= 2:
            soon.add(batch["food_id"])
    ranked, rejected = [], []
    for recipe in recipes:
        needed = requirements(recipe,servings)
        validation = compatibility(list(needed),foods,profile,rules)
        if validation["status"] == "not_compatible":
            rejected.append({"recipe_id":recipe["id"],"filters_failed":validation["reasons"]})
            continue
        if mode == 'plant_based' and any(foods[f].get('group') not in {'vegetable', 'fruit', 'legume', 'grain', 'oil', 'nuts', 'seed', 'herb'} for f in needed):
            continue
        coverage = sum(min(available.get(f,0)/q,1) for f,q in needed.items()) / max(len(needed),1)
        fully_available = sum(available.get(f,0) >= q for f,q in needed.items())
        if mode == "no_shopping" and fully_available < len(needed):
            rejected.append({"recipe_id":recipe["id"],"filters_failed":[{"code":"missing_ingredients"}]})
            continue
        if mode == "quick" and recipe["minutes"] > 15:
            continue
        expiring = sorted(set(needed) & soon)
        components = {"availability":coverage,"expiry":len(expiring)/max(len(needed),1),
                      "diet":max(0,min(validation["preference_matches"]/max(len(needed),1),1)-0.3*len(validation["warnings"])),
                      "speed":max(0,1-recipe["minutes"]/60)}
        score = sum(components[k]*v for k,v in profiles[weight_mode].items())
        ranked.append({"recipe":recipe,"score":round(score,6),"component_scores":components,
                       "available_count":fully_available,"ingredient_count":len(needed),"use_soon_food_ids":expiring,
                       "filters_passed":["canonical_ingredients","allergens","intolerances","published_diet_rules"],
                       "warnings":validation["warnings"],"minutes":recipe["minutes"],
                       "explanations":{"available":fully_available,"total":len(needed),"use_soon":expiring,"minutes":recipe["minutes"]}})
    ranked.sort(key=lambda r:(-r["score"],r["recipe"]["id"]))
    # Greedy diversification of the primary ingredient; preserve all filtered candidates.
    diverse, repeated, seen = [], [], set()
    for candidate in ranked:
        primary = candidate["recipe"]["ingredients"][0]["food_id"]
        (repeated if primary in seen else diverse).append(candidate)
        seen.add(primary)
    return diverse+repeated,rejected
