"""Typical household shelf life used to *estimate* a date when none is known.

Estimates are planning hints only: they are always stored with
expiry_kind="estimated", which the engine never treats as a safety date.
Values are conservative days for an unopened or freshly bought item.
"""
from datetime import date, timedelta

LOCATIONS = ("fridge", "freezer", "pantry")

# (fridge, freezer, pantry); None means the location is not suitable.
GROUP_DAYS = {
    "vegetable": (5, 240, None),
    "fruit": (5, 240, None),
    "mushroom": (4, 180, None),
    "herb": (7, 180, None),
    "meat": (2, 120, None),
    "fish": (1, 90, None),
    "dairy": (7, 90, None),
    "egg": (28, None, 14),
    "grain": (180, 365, 180),
    "legume": (4, 180, 365),
    "nuts": (270, 365, 180),
    "seed": (270, 365, 180),
    "spice": (None, None, 365),
    "condiment": (60, None, 180),
    "oil": (None, None, 365),
    "sweetener": (None, None, 730),
    "honey": (None, None, 730),
    "seaweed": (None, None, 365),
    "other": (7, 180, 180),
}

SLUG_DAYS = {
    "potato": (None, None, 30), "new-potato": (None, None, 21), "red-potato": (None, None, 30),
    "purple-potato": (None, None, 30), "sweet-potato": (None, None, 21), "purple-sweet-potato": (None, None, 21),
    "onion": (30, None, 30), "red-onion": (30, None, 30), "white-onion": (30, None, 30),
    "shallot": (30, None, 30), "garlic": (None, None, 60), "pumpkin": (None, None, 60),
    "butternut-squash": (None, None, 45), "banana": (None, None, 5), "avocado": (4, None, 4),
    "apple": (30, 240, 7), "pear": (14, 240, 5), "lemon": (21, None, 7), "orange": (21, None, 7),
    "lime": (21, None, 7), "carrot": (21, 240, None), "cabbage": (14, 240, None), "celery": (10, 240, None),
    "spinach": (3, 240, None), "arugula": (3, None, None), "lettuce": (4, None, None),
    "romaine-lettuce": (4, None, None), "iceberg-lettuce": (5, None, None), "berries": (3, 240, None),
    "raspberry": (2, 240, None), "strawberry": (3, 240, None), "blueberry": (7, 240, None),
    "tomato": (5, 240, 5), "cherry-tomato": (5, 240, 5),
    "ground-beef": (1, 90, None), "chicken": (2, 180, None), "turkey": (2, 180, None),
    "cooked-ham": (5, 60, None), "prosciutto": (7, 60, None), "pancetta": (14, 60, None),
    "bresaola": (7, 60, None), "smoked-salmon": (5, 60, None), "canned-tuna": (None, None, 730),
    "milk": (5, 90, None), "heavy-cream": (5, 90, None), "butter": (30, 180, None),
    "parmesan": (30, 180, None), "pecorino": (30, 180, None), "cheddar": (21, 180, None),
    "mozzarella": (3, 60, None), "burrata": (2, None, None), "stracciatella-cheese": (2, None, None),
    "ricotta": (3, 60, None), "mascarpone": (5, None, None), "plain-yogurt": (10, None, None),
    "greek-yogurt": (10, None, None), "skyr": (10, None, None), "kefir": (10, None, None),
    "tofu": (5, 90, None), "tempeh": (7, 90, None), "bread": (None, 90, 3), "wholegrain-bread": (None, 90, 4),
    "tortilla": (14, 90, 7), "potato-gnocchi": (5, 90, None), "yeast": (30, None, 365),
    "tomato-passata": (None, None, 365), "tomato-paste": (None, None, 365), "coconut-milk": (None, None, 365),
}


def shelf_life_days(food: dict) -> dict:
    """Per-location estimated days for a catalog food, e.g. {"fridge": 5, "freezer": 240}."""
    values = SLUG_DAYS.get(food.get("slug", "")) or GROUP_DAYS.get(food.get("group", "other"), GROUP_DAYS["other"])
    return {location: days for location, days in zip(LOCATIONS, values) if days}


def estimate_expiry(food: dict, location: str, today: date) -> str | None:
    """ISO date estimated from typical shelf life, or None when unsuitable/unknown."""
    days = shelf_life_days(food).get(location)
    return (today + timedelta(days=days)).isoformat() if days else None
