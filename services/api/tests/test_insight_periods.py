import unittest
import test_core as support
from eatme.validation import new_id
from eatme.storage import encode


class InsightPeriodCase(unittest.TestCase):
    setUp = support.EatMeCase.setUp
    add = support.EatMeCase.add
    assertCode = support.EatMeCase.assertCode
    prepare_bowl = support.EatMeCase.prepare_bowl
    confirmation = support.EatMeCase.confirmation

    def test_period_bounds_and_daily_counts_are_recorded_events(self):
        plan = self.prepare_bowl()
        cooking = self.service.cooking_confirm(self.user, self.confirmation(plan), new_id())
        with self.db.transaction() as tx:
            tx.execute('UPDATE cooking_sessions SET created_at=? WHERE id=?', ('2026-09-04T23:59:59+00:00', cooking['id']))
        result = self.service.insights(self.user, 7)
        self.assertEqual(result['cooked_meals'], 1)
        self.assertEqual(result['different_recipes'], 1)
        self.assertEqual(result['timeline'][0], {'date': '2026-09-04', 'cooked_meals': 1})
        self.assertEqual(len(result['timeline']), 7)
        with self.db.transaction() as tx:
            tx.execute('UPDATE cooking_sessions SET created_at=? WHERE id=?', ('2026-09-03T23:59:59+00:00', cooking['id']))
        self.assertEqual(self.service.insights(self.user, 7)['cooked_meals'], 0)
        self.assertEqual(self.service.insights(self.user, 30)['cooked_meals'], 1)
        self.assertEqual(len(self.service.insights(self.user, 90)['timeline']), 90)

    def test_missing_estimates_stay_null_and_external_preparation_is_excluded(self):
        plan = self.prepare_bowl()
        cooking = self.service.cooking_confirm(self.user, self.confirmation(plan), new_id())
        with self.db.transaction() as tx:
            tx.execute('UPDATE cooking_sessions SET created_at=?,data=? WHERE id=?', ('2026-09-10T10:00:00+00:00', encode({'source': 'external-preparation'}), cooking['id']))
        result = self.service.insights(self.user, 7)
        self.assertEqual(result['cooked_meals'], 0)
        self.assertIsNone(result['money_saved'])
        self.assertIsNone(result['carbon_saved'])
        self.assertCode('invalid_period', lambda: self.service.insights(self.user, 8))
        self.assertCode('invalid_period', lambda: self.service.insights(self.user, True))


if __name__ == '__main__':
    unittest.main()
