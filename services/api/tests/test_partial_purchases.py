import unittest
import test_domains as support
from eatme.catalog import identifier
from eatme.validation import new_id


class PartialPurchaseCase(unittest.TestCase):
    setUp = support.DomainCase.setUp
    assertCode = support.DomainCase.assertCode
    enable_plus = support.DomainCase.enable_plus
    meal = support.DomainCase.meal

    def test_partial_purchase_is_atomic_idempotent_and_versioned(self):
        row = self.app.shopping_action(self.owner, {'action': 'add', 'food_id': identifier('food', 'tomato'), 'quantity': '500'}, new_id())
        request = {'action': 'purchase', 'id': row['id'], 'expected_version': 1, 'purchase_quantity': '300'}
        key = new_id()
        first = self.app.shopping_action(self.owner, request, key)
        self.assertEqual(self.app.shopping_action(self.owner, request, key), first)
        remaining = self.app.shopping(self.owner)['items'][0]
        self.assertEqual(remaining['quantity'], '200')
        self.assertEqual(remaining['purchased_quantity'], '300')
        self.assertEqual(remaining['requested_quantity'], '500')
        self.assertEqual(remaining['version'], 2)
        self.assertFalse(remaining['checked'])
        self.assertEqual(sum(b['quantity_milli'] for b in self.app.inventory(self.owner)['items']), 300000)
        self.assertCode('stale_shopping_item', lambda: self.app.shopping_action(self.owner, request, new_id()))
        self.app.shopping_action(self.owner, {**request, 'expected_version': 2, 'purchase_quantity': '200'}, new_id())
        self.assertEqual(self.app.shopping(self.owner)['items'], [])
        self.assertEqual(sum(b['quantity_milli'] for b in self.app.inventory(self.owner)['items']), 500000)

    def test_recalculation_preserves_partial_purchase_and_remainder(self):
        self.enable_plus()
        request = {'meals': [self.meal()]}
        self.app.shopping_action(self.owner, {**request, 'action': 'generate'}, new_id())
        row = next(i for i in self.app.shopping(self.owner)['items'] if i['food_id'] == identifier('food', 'tomato'))
        self.app.shopping_action(self.owner, {'action': 'purchase', 'id': row['id'], 'expected_version': 1, 'purchase_quantity': '100'}, new_id())
        self.app.shopping_action(self.owner, {**request, 'action': 'generate'}, new_id())
        rows = [i for i in self.app.shopping(self.owner)['items'] if i['food_id'] == row['food_id']]
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]['quantity'], '100')
        self.assertEqual(rows[0]['purchased_quantity'], '100')

    def test_stock_consumed_after_partial_purchase_does_not_duplicate_line(self):
        self.enable_plus()
        request = {'meals': [self.meal()]}
        self.app.shopping_action(self.owner, {**request, 'action': 'generate'}, new_id())
        row = next(i for i in self.app.shopping(self.owner)['items'] if i['food_id'] == identifier('food', 'tomato'))
        self.app.shopping_action(self.owner, {'action': 'purchase', 'id': row['id'], 'expected_version': 1, 'purchase_quantity': '100'}, new_id())
        batch = self.app.inventory(self.owner)['items'][0]
        self.app.change_inventory(self.owner, batch['id'], {'action': 'consumed', 'quantity': '100', 'expected_version': 1}, new_id())
        preview = self.app.shopping_action(self.owner, {**request, 'action': 'preview_generate'}, new_id())
        self.assertEqual(next(i for i in preview['items'] if i['food_id'] == row['food_id'])['quantity'], '200')
        self.app.shopping_action(self.owner, {**request, 'action': 'generate', 'shopping_versions': preview['shopping_versions'], 'inventory_versions': preview['inventory_versions']}, new_id())
        rows = [i for i in self.app.shopping(self.owner)['items'] if i['food_id'] == row['food_id']]
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]['quantity'], '200')
        self.assertEqual(rows[0]['purchased_quantity'], '100')


if __name__ == '__main__':
    unittest.main()
