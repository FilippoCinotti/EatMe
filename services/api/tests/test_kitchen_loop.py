import unittest
import test_core as support
from eatme.storage import encode, decode
from eatme.validation import new_id


class KitchenLoopCase(unittest.TestCase):
    setUp = support.EatMeCase.setUp
    add = support.EatMeCase.add
    prepare_bowl = support.EatMeCase.prepare_bowl
    confirmation = support.EatMeCase.confirmation
    assertCode = support.EatMeCase.assertCode

    def plus(self):
        with self.db.transaction() as tx:
            tx.execute('INSERT INTO subscriptions VALUES (?,?,?,?)', (self.user, 'test', encode({'eatme_plus': {'active': True}}), '2026-09-10'))

    def test_leftover_location_date_and_provenance_are_atomic(self):
        plan = self.prepare_bowl()
        command = {**self.confirmation(plan), 'leftover_servings': 1, 'prepared_at': '2026-09-09', 'leftover_location': 'freezer'}
        key = new_id()
        result = self.service.cooking_confirm(self.user, command, key)
        self.assertEqual(self.service.cooking_confirm(self.user, command, key), result)
        leftover = self.service.leftovers(self.user)['items'][0]
        self.assertEqual(leftover['location'], 'freezer')
        self.assertEqual(leftover['prepared_at'], '2026-09-09')
        self.assertIsNone(leftover['user_use_date'])
        self.assertEqual(leftover['use_date_source'], 'unknown')
        with self.db.transaction() as tx:
            record = decode(tx.one('SELECT data FROM cooking_sessions WHERE id=?', (result['id'],))['data'])
        self.assertEqual(record['consumed_servings'], 1)
        self.assertEqual(len(self.service.leftovers(self.user)['items']), 1)

    def test_invalid_leftover_date_rolls_back_consumption(self):
        plan = self.prepare_bowl()
        before = self.service.inventory(self.user)
        self.assertCode('invalid_date', lambda: self.service.cooking_confirm(self.user, {
            **self.confirmation(plan), 'leftover_servings': 1, 'prepared_at': '2026-09-10', 'leftover_use_date': '2026-09-09'}, new_id()))
        self.assertEqual(self.service.inventory(self.user), before)

    def test_shopping_preview_is_read_only_and_checked_lines_survive(self):
        self.plus()
        meal = {'recipe_id': self.prepare_bowl()['recipe_id'], 'servings': 4}
        request = {'meals': [meal]}
        self.service.shopping_action(self.user, {**request, 'action': 'generate'}, new_id())
        first = self.service.shopping(self.user)['items'][0]
        self.service.shopping_action(self.user, {'action': 'check', 'id': first['id'], 'expected_version': first['version'], 'checked': True}, new_id())
        before = self.service.shopping(self.user)
        preview = self.service.shopping_action(self.user, {**request, 'action': 'preview_generate'}, new_id())
        self.assertEqual(self.service.shopping(self.user), before)
        self.service.shopping_action(self.user, {**request, 'action': 'generate', 'shopping_versions': preview['shopping_versions'], 'inventory_versions': preview['inventory_versions']}, new_id())
        checked = [r for r in self.service.shopping(self.user)['items'] if r['id'] == first['id']]
        self.assertTrue(checked[0]['checked'])
        self.assertCode('stale_shopping_item', lambda: self.service.shopping_action(self.user, {**request, 'action': 'generate', 'shopping_versions': preview['shopping_versions']}, new_id()))

    def test_estimated_and_corrected_consumption_are_distinguished(self):
        plan = self.prepare_bowl()
        food_id = plan['ingredients'][0]['food_id']
        self.assertTrue(all(i['quantity_source'] == 'estimated' for i in plan['ingredients']))
        corrected = self.service.cooking_preview(self.user, {'recipe_id': plan['recipe_id'], 'servings': 2, 'consumption': {food_id: '1'}})
        self.assertEqual(next(i for i in corrected['ingredients'] if i['food_id'] == food_id)['quantity_source'], 'confirmed')


if __name__ == '__main__':
    unittest.main()
