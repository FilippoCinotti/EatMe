"""Weekly shopping must not reload the full catalog for every meal."""
import unittest
from datetime import date, timedelta
from unittest.mock import patch

import test_domains as support
from eatme.catalog import identifier
from eatme.service import HEALTH_CONSENT
from eatme.validation import new_id


class ShoppingGenerationCase(unittest.TestCase):
    setUp = support.DomainCase.setUp
    assertCode = support.DomainCase.assertCode
    enable_plus = support.DomainCase.enable_plus
    join = support.DomainCase.join
    meal = support.DomainCase.meal

    def week(self):
        start = date(2026, 9, 11)
        return [
            {**self.meal(), 'date': (start + timedelta(days=day)).isoformat(), 'slot': slot}
            for day in range(7)
            for slot in ('breakfast', 'lunch', 'snack', 'dinner')
        ]

    def test_full_week_preview_and_confirmation_use_one_catalog_read_each(self):
        self.enable_plus()
        self.app.add_inventory(self.owner, {'food_id': identifier('food', 'tomato'), 'quantity': '100'}, new_id())
        plan = self.app.plan_action(self.owner, {
            'action': 'save', 'start_date': '2026-09-11', 'meals': self.week(),
        }, new_id())
        command = {'action': 'preview_generate', 'plan_id': plan['id']}
        with patch.object(self.app, '_catalog', wraps=self.app._catalog) as catalog:
            with patch.object(self.app, '_diners', wraps=self.app._diners) as diners:
                preview = self.app.shopping_action(self.owner, command, new_id())
        self.assertEqual(catalog.call_count, 1)
        self.assertEqual(diners.call_count, 1)
        self.assertEqual(self.app.shopping(self.owner)['items'], [])
        expected = {item['food_id']: item['quantity'] for item in preview['items']}
        self.assertEqual(expected[identifier('food', 'tomato')], '5500')
        confirm = {
            **command, 'action': 'generate', 'plan_version': preview['plan_version'],
            'shopping_versions': preview['shopping_versions'],
            'inventory_versions': preview['inventory_versions'],
        }
        key = new_id()
        with patch.object(self.app, '_catalog', wraps=self.app._catalog) as catalog:
            result = self.app.shopping_action(self.owner, confirm, key)
        self.assertEqual(catalog.call_count, 1)
        self.assertEqual(self.app.shopping_action(self.owner, confirm, key), result)
        self.assertEqual({item['food_id']: item['quantity'] for item in self.app.shopping(self.owner)['items']}, expected)

    def test_later_meal_still_checks_its_own_diners_and_rolls_back(self):
        self.enable_plus()
        self.join()
        self.app.household_action(self.guest, {
            'action': 'share_constraints', 'enabled': True, 'consent_version': 'household-constraints-1',
        }, new_id())
        profile = self.app.get_profile(self.guest)
        self.app.save_profile(self.guest, {
            'name': 'Guest', 'adult_confirmed': True, 'expected_version': profile['version'],
            'allergies': ['milk'], 'health_consent_version': HEALTH_CONSENT,
        }, new_id())
        meals = self.week()
        meals[-1] = {**meals[-1], 'recipe_id': identifier('recipe', 'tomato-feta'), 'participants': [self.guest]}
        for action in ('preview_generate', 'generate'):
            with self.subTest(action=action):
                self.assertCode('recipe_not_compatible', lambda: self.app.shopping_action(
                    self.owner, {'action': action, 'meals': meals}, new_id(),
                ))
                self.assertEqual(self.app.shopping(self.owner)['items'], [])

    def test_weekly_generation_requires_consent_for_each_distinct_diner_group(self):
        self.enable_plus()
        self.join()
        meals = self.week()
        meals[-1] = {**meals[-1], 'participants': [self.owner, self.guest]}
        self.assertCode('participant_consent_required', lambda: self.app.shopping_action(
            self.owner, {'action': 'generate', 'meals': meals}, new_id(),
        ))
        self.assertEqual(self.app.shopping(self.owner)['items'], [])


if __name__ == '__main__':
    unittest.main()
