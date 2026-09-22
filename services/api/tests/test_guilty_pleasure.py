import tempfile
import unittest
from datetime import date

from eatme.catalog import identifier, seed_catalog
from eatme.errors import DomainError
from eatme.planning import preference_mode
from eatme.service import HEALTH_CONSENT, MEDICAL_CONSENT, Service, new_id
from eatme.storage import Database, encode


class GuiltyPleasureTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.db = Database(self.temp.name + "/eatme.db")
        self.db.migrate_local()
        seed_catalog(self.db)
        self.day = date(2026, 9, 10)
        self.app = Service(self.db, clock=lambda: self.day)
        self.user = new_id()
        self.app.save_profile(self.user, {"name": "Alex", "adult_confirmed": True}, new_id())

    def update_profile(self, **changes):
        current = self.app.get_profile(self.user)
        settings = current["settings"]
        return self.app.save_profile(
            self.user,
            {
                "name": current["name"],
                "adult_confirmed": True,
                "expected_version": current["version"],
                **settings,
                **changes,
            },
            new_id(),
        )

    def test_relaxes_soft_ranking_only_and_never_mutates_profile(self):
        before = self.app.get_profile(self.user)
        self.app.preferences(
            self.user,
            {"expected_version": 0, "data": {"max_minutes": 15, "cuisines": ["Italian"]}},
            new_id(),
        )
        normal = self.app.recommendations(self.user, "for_you")
        relaxed = self.app.recommendations(self.user, "guilty_pleasure")
        self.assertLess(len(normal["items"]), len(relaxed["items"]))
        self.assertTrue(relaxed["preference_context"]["soft_preferences_relaxed"])
        self.assertTrue(relaxed["preference_context"]["hard_restrictions_active"])
        self.assertEqual(before, self.app.get_profile(self.user))

    def test_allergy_always_exclude_celiac_and_unknown_stay_blocked(self):
        self.update_profile(allergies=["milk"], health_consent_version=HEALTH_CONSENT)
        relaxed = self.app.recommendations(self.user, "guilty_pleasure")
        self.assertNotIn(
            identifier("recipe", "tomato-feta"),
            [item["recipe"]["id"] for item in relaxed["items"]],
        )

        tomato = identifier("food", "tomato")
        self.update_profile(never_suggest=[tomato], allergies=[])
        relaxed = self.app.recommendations(self.user, "guilty_pleasure")
        self.assertTrue(
            all(tomato not in {i["food_id"] for i in item["recipe"]["ingredients"]} for item in relaxed["items"])
        )

        self.update_profile(
            never_suggest=[],
            diets=[{"diet_id": identifier("diet", "celiac"), "strictness": "flexible"}],
            medical_consent_version=MEDICAL_CONSENT,
        )
        relaxed = self.app.recommendations(self.user, "guilty_pleasure")
        self.assertNotIn(
            identifier("recipe", "green-pasta"),
            [item["recipe"]["id"] for item in relaxed["items"]],
        )

        unknown_food, unknown_recipe = new_id(), new_id()
        with self.db.transaction() as tx:
            tx.execute(
                "INSERT INTO foods VALUES (?,?)",
                (unknown_food, encode({"id": unknown_food, "name": {"en": "Unknown"}, "unit": "g", "group": "other", "ingredient_status": "unknown", "allergens": [], "may_contain": [], "intolerances": []})),
            )
            tx.execute(
                "INSERT INTO recipes VALUES (?,?)",
                (unknown_recipe, encode({"id": unknown_recipe, "title": {"en": "Unknown bowl"}, "minutes": 5, "servings": 1, "ingredients": [{"food_id": unknown_food, "quantity": "10"}], "steps": {"en": ["Serve."]} })),
            )
        relaxed = self.app.recommendations(self.user, "guilty_pleasure")
        self.assertNotIn(unknown_recipe, [item["recipe"]["id"] for item in relaxed["items"]])

    def test_meal_and_day_scope_expire_without_affecting_other_days(self):
        overrides = [
            {"mode": "guilty_pleasure", "scope": "meal", "date": "2026-09-12", "slot": "dinner"},
            {"mode": "guilty_pleasure", "scope": "day", "date": "2026-09-13"},
        ]
        self.assertEqual(preference_mode(overrides, "2026-09-12", "dinner"), "guilty_pleasure")
        self.assertEqual(preference_mode(overrides, "2026-09-12", "lunch"), "for_you")
        self.assertEqual(preference_mode(overrides, "2026-09-13", "breakfast"), "guilty_pleasure")
        self.assertEqual(preference_mode(overrides, "2026-09-14", "dinner"), "for_you")

    def test_household_guest_allergy_cannot_be_relaxed(self):
        guest = new_id()
        self.app.save_profile(
            guest,
            {"name": "Guest", "adult_confirmed": True, "allergies": ["peanut"], "health_consent_version": HEALTH_CONSENT},
            new_id(),
        )
        invitation = self.app.household_action(self.user, {"action": "invite"}, new_id())
        self.app.household_action(guest, {"action": "accept", "token": invitation["token"]}, new_id())
        self.app.household_action(
            guest,
            {"action": "share_constraints", "enabled": True, "consent_version": "household-constraints-1"},
            new_id(),
        )
        with self.db.transaction() as tx:
            tx.execute(
                "INSERT INTO subscriptions VALUES (?,?,?,?)",
                (self.user, "revenuecat", encode({"eatme_plus": {"active": True}}), "2026-09-10T00:00:00+00:00"),
            )
        peanut_recipe = new_id()
        with self.db.transaction() as tx:
            tx.execute(
                "INSERT INTO recipes VALUES (?,?)",
                (peanut_recipe, encode({"id": peanut_recipe, "title": {"en": "Peanut bowl"}, "minutes": 20, "servings": 2, "ingredients": [{"food_id": identifier("food", "peanut"), "quantity": "50"}], "steps": {"en": ["Serve."]}})),
            )
        result = self.app.plan_action(
            self.user,
            {"action": "preview_generate", "start_date": "2026-09-10", "participants": [self.user, guest], "servings": 2, "mode": "guilty_pleasure"},
            new_id(),
        )
        self.assertNotIn(peanut_recipe, [meal["recipe_id"] for meal in result["data"]["meals"]])

    def test_invalid_override_cannot_target_another_meal(self):
        with self.assertRaises(DomainError) as caught:
            self.app.plan_action(
                self.user,
                {
                    "action": "save",
                    "start_date": "2026-09-10",
                    "meals": [],
                    "preference_overrides": [{"mode": "guilty_pleasure", "scope": "meal", "date": "2026-09-10", "slot": "dinner"}],
                },
                new_id(),
            )
        self.assertEqual(caught.exception.code, "invalid_preference_override")


if __name__ == "__main__":
    unittest.main()
