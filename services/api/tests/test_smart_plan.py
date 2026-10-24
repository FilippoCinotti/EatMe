"""Smart Plan persistence, compatibility and conflict regression tests."""
import unittest
from copy import deepcopy

import test_domains as support
from eatme.validation import new_id


class SmartPlanCase(unittest.TestCase):
    assertCode = support.DomainCase.assertCode
    meal = support.DomainCase.meal
    enable_plus = support.DomainCase.enable_plus
    def setUp(self):
        support.DomainCase.setUp(self)
        self.enable_plus()
        self.plan = self.app.plan_action(self.owner, {
            'action': 'save', 'start_date': '2026-09-11',
            'meals': [self.meal(), {**self.meal('tomato-feta'), 'date': '2026-09-12'}],
        }, new_id())

    def act(self, action, **fields):
        result = self.app.plan_action(self.owner, {
            'action': action, 'id': self.plan['id'], 'expected_version': self.plan['version'],
            'date': '2026-09-11', 'slot': 'dinner', **fields,
        }, new_id())
        if 'data' in result and not result.get('preview'):
            self.plan = result
        return result

    def test_lock_survives_reload_and_regeneration(self):
        self.act('lock', locked=True)
        locked = deepcopy(self.plan['data']['meals'][0])
        self.assertEqual(self.app.plans(self.owner)['items'][0]['data']['meals'][0], locked)
        preview = self.act('preview_generate', start_date='2026-09-11')
        self.assertIn(locked, preview['data']['meals'])
        self.assertCode('meal_locked', lambda: self.act('skip'))
        self.assertCode('meal_locked', lambda: self.act('save', start_date='2026-09-11', meals=[]))
        self.act('lock', locked=False)
        self.act('skip')
        self.assertEqual(len(self.plan['data']['meals']), 1)

    def test_suggestion_is_read_only_and_replaces_one_meal(self):
        original = deepcopy(self.plan)
        suggestion = self.act('suggest_alternative')
        self.assertNotEqual(suggestion['meal']['recipe_id'], original['data']['meals'][0]['recipe_id'])
        self.assertEqual(self.app.plans(self.owner)['items'][0]['version'], original['version'])
        self.act('replace', recipe_id=suggestion['meal']['recipe_id'])
        self.assertEqual(self.plan['data']['meals'][1], original['data']['meals'][1])
        self.assertEqual(self.plan['data']['meals'][0]['servings'], 2)

    def test_swap_copy_move_and_occupied_target(self):
        self.assertCode('meal_slot_occupied', lambda: self.act('move', target_date='2026-09-12', target_slot='dinner'))
        original = deepcopy(self.plan['data']['meals'])
        self.act('swap', target_date='2026-09-12', target_slot='dinner')
        self.assertEqual(self.plan['data']['meals'][0]['recipe_id'], original[0]['recipe_id'])
        self.assertEqual(self.plan['data']['meals'][0]['date'], '2026-09-12')
        self.act('copy', target_date='2026-09-13', target_slot='dinner')
        self.assertEqual(len(self.plan['data']['meals']), 3)
        self.act('move', target_date='2026-09-14', target_slot='dinner')
        self.assertEqual(len(self.plan['data']['meals']), 3)
        self.assertCode('invalid_meal_slot', lambda: self.act('copy', date='2026-09-14', target_date='2026-09-20', target_slot='dinner'))

    def test_stale_requests_and_retries(self):
        command = {'action': 'lock', 'id': self.plan['id'], 'expected_version': self.plan['version'],
                   'date': '2026-09-11', 'slot': 'dinner', 'locked': True}
        key = new_id()
        result = self.app.plan_action(self.owner, command, key)
        self.assertEqual(self.app.plan_action(self.owner, command, key), result)
        self.assertCode('stale_plan', lambda: self.app.plan_action(self.owner, command, new_id()))
        self.assertCode('plan_not_found', lambda: self.app.plan_action(self.guest, command, new_id()))

    def test_daily_limits_filter_week_and_invalid_input(self):
        result = self.act('preview_generate', start_date='2026-09-11', daily_limits={'2026-09-13': 1})
        self.assertFalse(any(m['date'] == '2026-09-13' for m in result['data']['meals']))
        self.assertCode('invalid_time_limits', lambda: self.act('set_time_limits', daily_limits={'2026-10-01': 20}))
        self.assertCode('invalid_number', lambda: self.act('set_time_limits', daily_limits={'2026-09-11': True}))
        self.act('set_time_limits', daily_limits={'2026-09-11': None})
        self.assertIsNone(self.app.plans(self.owner)['items'][0]['data']['daily_limits']['2026-09-11'])

    def test_locked_destination_cannot_be_swapped_or_overwritten(self):
        self.act('lock', date='2026-09-12', locked=True)
        self.assertCode('meal_locked', lambda: self.act('swap', target_date='2026-09-12', target_slot='dinner'))

    def test_alternative_requires_premium(self):
        with self.db.transaction() as tx:
            tx.execute('DELETE FROM subscriptions WHERE user_id=?', (self.owner,))
        self.assertCode('eatme_plus_required', lambda: self.act('suggest_alternative'))


if __name__ == '__main__':
    unittest.main()
