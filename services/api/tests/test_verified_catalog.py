import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

from eatme.catalog import identifier
from eatme.service import Service
from eatme.storage import Database

ROOT = Path(__file__).resolve().parents[3]
CATALOG = ROOT / "generated" / "verified_recipes_catalog.json"
MEAL_TYPES = {"breakfast", "snack", "lunch", "merenda", "dinner"}


def loader():
    spec = importlib.util.spec_from_file_location("load_verified_recipes", ROOT / "scripts" / "load_verified_recipes.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class VerifiedCatalogCase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog = json.loads(CATALOG.read_text())
        cls.food_ids = {item["id"] for item in json.loads((ROOT / "scripts" / "catalog_image_targets.json").read_text())}

    def test_records_are_unique_bilingual_and_source_backed(self):
        recipes = self.catalog["recipes"]
        self.assertEqual(len({r["id"] for r in recipes}), len(recipes))
        self.assertEqual(len({r["slug"] for r in recipes}), len(recipes))
        for recipe in recipes:
            with self.subTest(recipe["slug"]):
                self.assertEqual(recipe["id"], identifier("recipe", recipe["slug"]))
                self.assertTrue(recipe["source_url"].startswith("https://"))
                self.assertTrue(recipe["recommendation_eligible"])
                self.assertEqual(recipe["status"], "verified")
                self.assertTrue(recipe["title"]["it"] and recipe["title"]["en"])
                self.assertEqual(len(recipe["steps"]["it"]), len(recipe["steps"]["en"]))
                self.assertTrue(set(recipe["meal_types"]) <= MEAL_TYPES and recipe["meal_types"])
                self.assertTrue({item["food_id"] for item in recipe["ingredients"]} <= self.food_ids)

    def test_meal_slots_are_all_covered(self):
        slots = {slot for recipe in self.catalog["recipes"] for slot in recipe["meal_types"]}
        self.assertEqual(slots, MEAL_TYPES)

    def test_loader_rows_pass_recipe_validation(self):
        module = loader()
        units = {item["food_id"]: item["unit"] for r in self.catalog["recipes"] for item in r["ingredients"]}
        foods = {food_id: {"unit": unit} for food_id, unit in units.items()}
        rows, skipped = module.build_rows(self.catalog, foods)
        self.assertEqual(skipped, [])
        with tempfile.TemporaryDirectory() as directory:
            service = Service(Database(directory + "/eatme.db"))
            for row in rows:
                with self.subTest(row["slug"]):
                    service._validate_recipe(row, foods)

    def test_loader_skips_recipes_with_unknown_foods(self):
        module = loader()
        rows, skipped = module.build_rows(self.catalog, {})
        self.assertEqual(rows, [])
        self.assertEqual(len(skipped), len(self.catalog["recipes"]))


if __name__ == "__main__":
    unittest.main()
