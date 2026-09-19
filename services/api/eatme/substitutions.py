"""Reviewable canonical substitutions for imported recipe adaptation.

These mappings describe a limited culinary role, not nutritional equivalence.
Every candidate is re-evaluated by the normal compatibility engine before it
is returned and the complete edited recipe is checked again after selection.
"""

CURATED_SUBSTITUTIONS = {
    "pasta": [
        {"slug": "rice", "role": "starch_base", "review": "culinary-review-2026-09"},
    ],
    "feta": [
        {"slug": "chickpea", "role": "salad_component", "review": "culinary-review-2026-09"},
    ],
    "chicken": [
        {"slug": "chickpea", "role": "protein_component", "review": "culinary-review-2026-09"},
        {"slug": "egg", "role": "protein_component", "review": "culinary-review-2026-09"},
    ],
}

HARD_SAFETY_CODES = {
    "contains_allergen",
    "may_contain_allergen",
    "intolerance_conflict",
    "never_suggest",
    "ethical_exclusion",
}


def conflict_class(code, *, medical=False):
    if code in HARD_SAFETY_CODES or medical:
        return "hard_safety"
    if code == "diet_exclusion":
        return "diet"
    if code in {"unknown_ingredient", "rule_not_evaluable"}:
        return "unknown"
    return "lifestyle"
