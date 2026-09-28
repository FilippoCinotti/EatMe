import tempfile
import unittest
from datetime import date

from eatme.catalog import identifier, seed_catalog
from eatme.errors import DomainError
from eatme.service import Service, new_id
from eatme.shelf_life import estimate_expiry, shelf_life_days
from eatme.storage import Database


class UpkeepCase(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        db = Database(self.temp.name + "/eatme.db")
        db.migrate_local()
        seed_catalog(db)
        self.service = Service(db, clock=lambda: date(2026, 9, 10))
        self.user = new_id()
        self.service.save_profile(self.user, dict(name="Alex", adult_confirmed=True, household_size=2, diets=[
            dict(diet_id=identifier("diet", "mediterranean"), strictness="standard")]), new_id())

    def add(self, slug, amount, **kwargs):
        return self.service.add_inventory(self.user, dict(food_id=food(slug), quantity=str(amount), **kwargs), new_id())

    def confirmation(self, plan):
        return dict(recipe_id=plan["recipe_id"], servings=plan["servings"], profile_version=plan["profile_version"],
                    diet_rules_version=plan["diet_rules_version"],
                    batch_versions={a["batch_id"]: a["version"] for a in plan["allocations"]})

    def assertCode(self, code, fn):
        with self.assertRaises(DomainError) as raised:
            fn()
        self.assertEqual(raised.exception.code, code)


def food(slug):
    return identifier("food", slug)


class PantryStapleTests(UpkeepCase):
    def set_pantry(self, *slugs, version=0):
        return self.service.pantry_action(self.user, {"action": "set", "food_ids": [food(s) for s in slugs],
                                                      "expected_version": version}, new_id())

    def test_pantry_starts_unconfigured_with_catalog_suggestions(self):
        pantry = self.service.pantry(self.user)
        self.assertFalse(pantry["configured"])
        self.assertEqual(pantry["food_ids"], [])
        self.assertIn("olive-oil", [f["slug"] for f in pantry["suggestions"]])

    def test_set_is_versioned_and_validated(self):
        self.assertEqual(self.set_pantry("olive-oil")["version"], 1)
        self.assertCode("stale_pantry", lambda: self.set_pantry("rice"))
        self.set_pantry("olive-oil", "rice", version=1)
        pantry = self.service.pantry(self.user)
        self.assertTrue(pantry["configured"])
        self.assertEqual(pantry["food_ids"], [food("olive-oil"), food("rice")])
        self.assertCode("invalid_food", lambda: self.service.pantry_action(
            self.user, {"action": "set", "food_ids": [new_id()], "expected_version": 2}, new_id()))

    def test_staples_complete_a_no_shopping_recipe(self):
        self.add("tomato", 200)
        self.add("chickpea", 300)
        bowl = identifier("recipe", "sunny-bowl")
        before = self.service.recommendations(self.user, "no_shopping")["items"]
        self.assertNotIn(bowl, [i["recipe"]["id"] for i in before])
        self.set_pantry("olive-oil")
        items = self.service.recommendations(self.user, "no_shopping")["items"]
        bowl_item = next(i for i in items if i["recipe"]["id"] == bowl)
        self.assertEqual(bowl_item["pantry_food_ids"], [food("olive-oil")])

    def test_staples_alone_never_make_a_recipe_fridge_relevant(self):
        self.set_pantry("olive-oil", "tomato", "chickpea")
        self.add("milk", 500)
        ids = [i["recipe"]["id"] for i in self.service.recommendations(self.user, "for_you")["items"]]
        self.assertNotIn(identifier("recipe", "sunny-bowl"), ids)

    def test_cooking_does_not_require_or_consume_staples(self):
        self.add("tomato", 200)
        self.add("chickpea", 300)
        self.set_pantry("olive-oil")
        plan = self.service.cooking_preview(self.user, dict(recipe_id=identifier("recipe", "sunny-bowl"), servings=2))
        self.assertEqual(plan["shortages"], [])
        oil = next(i for i in plan["ingredients"] if i["food_id"] == food("olive-oil"))
        self.assertTrue(oil["pantry"])
        self.service.cooking_confirm(self.user, self.confirmation(plan), new_id())


class EstimatedExpiryTests(UpkeepCase):
    def test_shelf_life_uses_group_defaults_and_overrides(self):
        today = date(2026, 9, 10)
        self.assertEqual(shelf_life_days({"slug": "tomato", "group": "vegetable"})["fridge"], 5)
        self.assertEqual(estimate_expiry({"slug": "x", "group": "meat"}, "fridge", today), "2026-09-12")
        self.assertIsNone(estimate_expiry({"slug": "x", "group": "meat"}, "pantry", today))

    def test_add_inventory_estimates_only_when_asked_and_date_unknown(self):
        estimated = self.add("tomato", 100, estimate_expiry=True)
        plain = self.add("tomato", 100)
        explicit = self.add("tomato", 100, estimate_expiry=True, expiry_date="2026-09-20", expiry_kind="best_before")
        batches = {b["id"]: b for b in self.service.inventory(self.user)["items"]}
        self.assertEqual((batches[estimated["id"]]["expiry_date"], batches[estimated["id"]]["expiry_kind"]),
                         ("2026-09-15", "estimated"))
        self.assertEqual(batches[plain["id"]]["expiry_kind"], "unknown")
        self.assertEqual(batches[explicit["id"]]["expiry_kind"], "best_before")

    def test_unsuitable_location_keeps_date_unknown(self):
        batch = self.add("chicken", 200, location="pantry", estimate_expiry=True)
        stored = next(b for b in self.service.inventory(self.user)["items"] if b["id"] == batch["id"])
        self.assertEqual(stored["expiry_kind"], "unknown")

    def test_catalog_exposes_shelf_life(self):
        tomato = next(f for f in self.service.catalog()["foods"] if f["slug"] == "tomato")
        self.assertEqual(tomato["shelf_life_days"], {"fridge": 5, "freezer": 240, "pantry": 5})


class PurchaseManyTests(UpkeepCase):
    def line(self, **data):
        return self.service.shopping_action(self.user, {"action": "add", "quantity": "2", **data}, new_id())

    def test_checked_lines_move_to_fridge_with_estimated_dates(self):
        tomato = self.line(food_id=food("tomato"), quantity="300")
        label = self.line(label="Kitchen paper")
        command = {"action": "purchase_many", "items": [{"id": tomato["id"], "expected_version": 1},
                                                        {"id": label["id"], "expected_version": 1}]}
        key = new_id()
        result = self.service.shopping_action(self.user, command, key)
        self.assertEqual(self.service.shopping_action(self.user, command, key), result)
        self.assertEqual([p["food_id"] for p in result["purchased"]], [food("tomato")])
        self.assertEqual(result["purchased"][0]["expiry_date"], "2026-09-15")
        self.assertEqual(result["skipped"][0]["reason"], "canonical_food_required")
        batch = next(b for b in self.service.inventory(self.user)["items"] if b["id"] == result["purchased"][0]["batch_id"])
        self.assertEqual((batch["provenance"], batch["expiry_kind"]), ("shopping", "estimated"))
        remaining = [i["label"] for i in self.service.shopping(self.user)["items"]]
        self.assertEqual(remaining, ["Kitchen paper"])

    def test_stale_line_rolls_back_the_whole_purchase(self):
        first = self.line(food_id=food("tomato"))
        second = self.line(food_id=food("zucchini"))
        items = [{"id": first["id"], "expected_version": 1}, {"id": second["id"], "expected_version": 7}]
        self.assertCode("stale_shopping_item", lambda: self.service.shopping_action(
            self.user, {"action": "purchase_many", "items": items}, new_id()))
        self.assertEqual(len(self.service.shopping(self.user)["items"]), 2)
        self.assertEqual(self.service.inventory(self.user)["items"], [])

    def test_estimate_can_be_disabled(self):
        line = self.line(food_id=food("tomato"))
        result = self.service.shopping_action(self.user, {"action": "purchase_many", "estimate_expiry": False,
                                                          "items": [{"id": line["id"], "expected_version": 1}]}, new_id())
        self.assertEqual(result["purchased"][0]["expiry_kind"], "unknown")

    def test_invalid_payloads_are_rejected(self):
        line = self.line(food_id=food("tomato"))
        for items in ([], "x", [{"id": line["id"], "expected_version": 1}] * 2):
            self.assertCode("invalid_items", lambda items=items: self.service.shopping_action(
                self.user, {"action": "purchase_many", "items": items}, new_id()))
