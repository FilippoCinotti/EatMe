import json
import tempfile
import unittest
from datetime import date
from unittest.mock import patch

from eatme.catalog import identifier, seed_catalog
from eatme.errors import DomainError
from eatme.service import HEALTH_CONSENT, Service, new_id
from eatme.storage import Database, encode


def page(recipe=None, *, description="", title="Source recipe"):
    metadata = (
        f'<meta property="og:title" content="{title}">'
        f'<meta property="og:description" content="{description}">'
        '<meta property="og:image" content="https://images.example/recipe.jpg">'
    )
    script = "" if recipe is None else '<script type="application/ld+json">' + json.dumps(recipe) + '</script>'
    return ("<html><head>" + metadata + script + "</head></html>").encode()


class SocialImportCase(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.db = Database(self.temp.name + "/eatme.db")
        self.db.migrate_local()
        seed_catalog(self.db)
        self.service = Service(self.db, clock=lambda: date(2026, 9, 14))
        self.user = new_id()
        self.profile = {"name": "Alex", "adult_confirmed": True, "household_size": 1, "diets": []}
        self.service.save_profile(self.user, self.profile, new_id())
        self.recipe = {
            "@type": "Recipe",
            "name": "Tomato and feta pasta",
            "author": {"name": "Public creator"},
            "recipeYield": "2 servings",
            "totalTime": "PT25M",
            "recipeIngredient": ["160 g pasta", "200 g tomatoes", "100 g feta"],
            "recipeInstructions": [{"text": "Cook the pasta."}, {"text": "Combine and serve."}],
        }

    def assert_code(self, code, call):
        with self.assertRaises(DomainError) as raised:
            call()
        self.assertEqual(raised.exception.code, code)

    def update_profile(self, **changes):
        current = self.service.get_profile(self.user)
        self.service.save_profile(
            self.user,
            {**self.profile, "expected_version": current["version"], **changes},
            new_id(),
        )

    def youtube(self):
        with patch("eatme.content.https_request", return_value=page(self.recipe)):
            return self.service.import_url(
                self.user,
                {"url": "https://www.youtube.com/watch?v=public", "private_use_confirmed": True},
            )

    def test_public_youtube_extracts_attribution_and_exact_mappings_without_saving(self):
        result = self.youtube()
        self.assertEqual(result["source_platform"], "youtube")
        self.assertEqual(result["source_creator"], "Public creator")
        self.assertEqual([row["mapping_status"] for row in result["ingredient_rows"]], ["matched"] * 3)
        with self.db.transaction() as tx:
            self.assertEqual(tx.one("SELECT COUNT(*) AS n FROM content_ownership WHERE kind='recipe'")["n"], 0)

    def test_free_import_allowance_is_centralized_and_plus_is_unlimited(self):
        with patch("eatme.content.https_request", return_value=page(self.recipe)):
            for index in range(3):
                self.service.import_url(
                    self.user,
                    {
                        "url": f"https://www.youtube.com/watch?v=public-{index}",
                        "private_use_confirmed": True,
                    },
                )
            self.assertEqual(self.service.entitlements(self.user)["remaining"]["smart_import"], 0)
            self.assert_code(
                "smart_import_limit_reached",
                lambda: self.service.import_url(
                    self.user,
                    {"url": "https://youtu.be/fourth", "private_use_confirmed": True},
                ),
            )
            with self.db.transaction() as tx:
                tx.execute(
                    "INSERT INTO subscriptions VALUES (?,?,?,?)",
                    (
                        self.user,
                        "revenuecat",
                        encode({"eatme_plus": {"active": True}}),
                        "2026-09-16T00:00:00+00:00",
                    ),
                )
            result = self.service.import_url(
                self.user,
                {"url": "https://youtu.be/fourth", "private_use_confirmed": True},
            )
            self.assertEqual(result["source_platform"], "youtube")
            self.assertEqual(self.service.entitlements(self.user)["tier"], "eatme_plus")

    def test_public_instagram_caption_can_be_partially_extracted(self):
        description = "Ingredients:\n200 g tomatoes\na handful of mystery herb\nMethod:\nMix everything."
        with patch("eatme.content.https_request", return_value=page(description=description)):
            result = self.service.import_url(
                self.user,
                {"url": "https://www.instagram.com/reel/public-id", "private_use_confirmed": True},
            )
        self.assertEqual(result["source_platform"], "instagram")
        self.assertEqual(result["ingredient_rows"][0]["mapping_status"], "matched")
        self.assertEqual(result["ingredient_rows"][1]["mapping_status"], "unknown")
        self.assertTrue(result["requires_mapping"])

    def test_public_recipe_page_uses_structured_data(self):
        with patch("eatme.content.https_request", return_value=page(self.recipe)):
            result = self.service.import_url(
                self.user,
                {
                    "url": "https://recipes.example/lemon-pasta",
                    "private_use_confirmed": True,
                },
            )
        self.assertEqual(result["source_platform"], "web")
        self.assertEqual(result["provenance"], "public-recipe-link")
        self.assertEqual(result["source_creator"], "Public creator")
        self.assertEqual(len(result["ingredient_rows"]), 3)

    def test_unsupported_private_deleted_and_network_failures_are_distinct(self):
        self.assert_code(
            "unsupported_recipe_source",
            lambda: self.service.import_url(
                self.user,
                {"url": "https://localhost/recipe", "private_use_confirmed": True},
            ),
        )
        with patch("eatme.content.https_request", return_value=b"<html>login required</html>"):
            self.assert_code(
                "source_private_or_unavailable",
                lambda: self.service.import_url(
                    self.user,
                    {"url": "https://instagram.com/p/private", "private_use_confirmed": True},
                ),
            )
        for code, status in (("provider_not_found", 404), ("provider_unavailable", 502)):
            with patch("eatme.content.https_request", side_effect=DomainError(code, status)):
                self.assert_code(
                    code,
                    lambda: self.service.import_url(
                        self.user,
                        {"url": "https://youtu.be/deleted", "private_use_confirmed": True},
                    ),
                )

    def test_mapping_review_compatibility_inventory_and_substitution_recheck(self):
        self.update_profile(diets=[{"diet_id": identifier("diet", "vegan"), "strictness": "strict"}])
        draft = self.youtube()
        tomato = identifier("food", "tomato")
        self.service.add_inventory(
            self.user,
            {"food_id": tomato, "quantity": "300", "expiry_date": "2026-09-15", "expiry_kind": "best_before"},
            new_id(),
        )
        first = self.service.import_review(self.user, {"ingredient_rows": draft["ingredient_rows"]})
        self.assertEqual(first["compatibility"]["status"], "conflict")
        self.assertEqual(first["inventory"]["available_count"], 1)
        feta = identifier("food", "feta")
        suggestion = next(item for item in first["substitutions"] if item["food_id"] == feta)
        self.assertEqual([item["food"]["slug"] for item in suggestion["candidates"]], ["chickpea"])
        adapted = []
        for row in draft["ingredient_rows"]:
            if row["food_id"] == feta:
                row = {**row, "food_id": identifier("food", "chickpea"), "mapping_status": "matched", "confirmed": True}
            adapted.append(row)
        second = self.service.import_review(self.user, {"ingredient_rows": adapted})
        self.assertEqual(second["compatibility"]["status"], "fit")
        self.assertNotEqual(first["inventory"], second["inventory"])

    def test_unknown_manual_override_allergy_intolerance_and_no_substitute(self):
        self.update_profile(allergies=["peanut"], intolerances=["lactose"], health_consent_version=HEALTH_CONSENT)
        rows = [
            {"food_id": identifier("food", "peanut"), "quantity": "50", "mapping_status": "matched", "confirmed": True, "source_text": "50 g peanuts"},
            {"food_id": identifier("food", "milk"), "quantity": "100", "mapping_status": "matched", "confirmed": True, "source_text": "100 ml milk"},
            {"food_id": None, "quantity": None, "mapping_status": "unknown", "confirmed": False, "source_text": "secret spice"},
        ]
        result = self.service.import_review(self.user, {"ingredient_rows": rows})
        codes = {reason["code"] for reason in result["compatibility"]["classified_reasons"]}
        self.assertTrue({"contains_allergen", "intolerance_conflict"} <= codes)
        self.assertEqual(result["inventory"]["unresolved_count"], 1)
        self.assertTrue(all(not item["candidates"] for item in result["substitutions"]))
        rows[2] = {"food_id": identifier("food", "tomato"), "quantity": "100", "mapping_status": "matched", "confirmed": True, "source_text": "100 g tomatoes"}
        overridden = self.service.import_review(self.user, {"ingredient_rows": rows})
        self.assertEqual(overridden["inventory"]["unresolved_count"], 0)

    def test_multiple_candidates_and_adapted_recipe_save_preserve_source(self):
        rows = [{"food_id": identifier("food", "chicken"), "quantity": "100", "mapping_status": "matched", "confirmed": True, "source_text": "100 g chicken"}]
        self.update_profile(diets=[{"diet_id": identifier("diet", "vegetarian"), "strictness": "strict"}])
        review = self.service.import_review(self.user, {"ingredient_rows": rows})
        self.assertEqual(len(review["substitutions"][0]["candidates"]), 2)
        for slug, amount in (("rice", "100"), ("tomato", "100")):
            self.service.add_inventory(self.user, {"food_id": identifier("food", slug), "quantity": amount}, new_id())
        recipe = {
            "title": "Adapted public recipe",
            "servings": 1,
            "minutes": 10,
            "ingredients": [
                {"food_id": identifier("food", "rice"), "quantity": "100"},
                {"food_id": identifier("food", "tomato"), "quantity": "100"},
            ],
            "steps": ["Cook and combine."],
            "source_url": "https://youtu.be/public",
            "source_platform": "youtube",
            "source_title": "Original public recipe",
            "source_creator": "Public creator",
            "source_thumbnail_url": "https://images.example/recipe.jpg",
            "imported_at": "2026-09-14T12:00:00+00:00",
            "provenance": "public-social-link",
            "adaptations": [{"from_food_id": identifier("food", "chicken"), "to_food_id": identifier("food", "rice"), "role": "protein_component"}],
        }
        saved = self.service.recipe_action(self.user, {"action": "save", "recipe": recipe}, new_id())
        opened = self.service.recipe(self.user, saved["id"])
        self.assertEqual(opened["source_url"], recipe["source_url"])
        self.assertEqual(opened["adaptations"], recipe["adaptations"])
        preview = self.service.cooking_preview(self.user, {"recipe_id": saved["id"], "servings": 1})
        self.assertFalse(preview["shortages"])

    def test_known_conflict_requires_explicit_acknowledgement_to_save(self):
        self.update_profile(allergies=["milk"], health_consent_version=HEALTH_CONSENT)
        recipe = {
            "title": "Feta plate", "servings": 1, "minutes": 5,
            "ingredients": [{"food_id": identifier("food", "feta"), "quantity": "100"}],
            "steps": ["Serve."], "source_url": "https://youtu.be/public",
        }
        self.assert_code(
            "recipe_not_compatible",
            lambda: self.service.recipe_action(self.user, {"action": "save", "recipe": recipe}, new_id()),
        )
        saved = self.service.recipe_action(
            self.user,
            {"action": "save", "recipe": recipe, "safety_acknowledged": True},
            new_id(),
        )
        self.assertTrue(saved["safety_acknowledged"])


class SavingsCase(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.db = Database(self.temp.name + "/eatme.db")
        self.db.migrate_local()
        seed_catalog(self.db)
        self.today = date.today()
        self.service = Service(self.db, clock=lambda: self.today)
        self.user = new_id()
        self.service.save_profile(self.user, {"name": "Alex", "adult_confirmed": True}, new_id())

    def test_estimates_use_recorded_cost_and_versioned_carbon_factor(self):
        batch = self.service.add_inventory(
            self.user,
            {"food_id": identifier("food", "tomato"), "quantity": "100", "expiry_date": self.today.isoformat(), "expiry_kind": "best_before"},
            new_id(),
        )
        self.service.inventory_metadata(
            self.user,
            {"id": batch["id"], "expected_version": 1, "metadata": {"cost": "2", "currency": "EUR"}},
            new_id(),
        )
        self.service.change_inventory(
            self.user,
            batch["id"],
            {"action": "consumed", "quantity": "50", "expected_version": 2},
            new_id(),
        )
        result = self.service.insights(self.user)
        self.assertEqual(result["money_saved"]["amounts"], [{"currency": "EUR", "value": "1.00"}])
        self.assertEqual(result["carbon_saved"]["value"], "0.10")
        self.assertEqual(result["carbon_saved"]["factor_version"], "poore-nemecek-owid-2019-v1")

    def test_insufficient_dates_costs_or_factors_remain_unavailable(self):
        batch = self.service.add_inventory(
            self.user,
            {"food_id": identifier("food", "egg"), "quantity": "2"},
            new_id(),
        )
        self.service.change_inventory(
            self.user,
            batch["id"],
            {"action": "consumed", "quantity": "1", "expected_version": 1},
            new_id(),
        )
        result = self.service.insights(self.user)
        self.assertIsNone(result["money_saved"])
        self.assertIsNone(result["carbon_saved"])

    def test_recorded_value_never_exceeds_batch_cost_across_events(self):
        batch = self.service.add_inventory(
            self.user,
            {"food_id": identifier("food", "tomato"), "quantity": "100", "expiry_date": self.today.isoformat(), "expiry_kind": "best_before"},
            new_id(),
        )
        self.service.inventory_metadata(
            self.user,
            {"id": batch["id"], "expected_version": 1, "metadata": {"cost": "3", "currency": "EUR"}},
            new_id(),
        )
        self.service.change_inventory(
            self.user, batch["id"],
            {"action": "consumed", "quantity": "60", "expected_version": 2}, new_id(),
        )
        self.service.change_inventory(
            self.user, batch["id"],
            {"action": "corrected", "quantity": "100", "expected_version": 3}, new_id(),
        )
        self.service.change_inventory(
            self.user, batch["id"],
            {"action": "consumed", "quantity": "80", "expected_version": 4}, new_id(),
        )
        result = self.service.insights(self.user)
        self.assertEqual(result["money_saved"]["amounts"], [{"currency": "EUR", "value": "3.00"}])


if __name__ == "__main__":
    unittest.main()
