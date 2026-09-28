"""Live PostgreSQL transaction checks; executed by the database CI job."""
import os
import unittest
from concurrent.futures import ThreadPoolExecutor

from eatme.catalog import identifier, seed_catalog
from eatme.service import Service, new_id
from eatme.storage import Database


@unittest.skipUnless(os.getenv('EATME_TEST_POSTGRES'), 'Requires the PostgreSQL CI database')
class PostgresTransactions(unittest.TestCase):
    def test_concurrent_purchase_replay_creates_one_batch(self):
        service = Service(Database(os.environ['EATME_TEST_POSTGRES']))
        seed_catalog(service.db)
        user_id = new_id()
        service.save_profile(user_id, {'name': 'Transaction test', 'adult_confirmed': True}, new_id())
        self.addCleanup(service.delete_account, user_id)
        line = service.shopping_action(user_id, {'action': 'add', 'food_id': identifier('food', 'tomato'), 'quantity': '250'}, new_id())
        operation = new_id()
        purchase = {'action': 'purchase', 'id': line['id'], 'expected_version': 1}
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(lambda _: service.shopping_action(user_id, purchase, operation), range(2)))
        self.assertEqual(results[0], results[1])
        stock = service.inventory(user_id)['items']
        self.assertEqual(len(stock), 1)
        self.assertEqual(stock[0]['quantity_milli'], 250000)

    def test_pantry_staples_and_bulk_purchase_under_backend_role(self):
        service = Service(Database(os.environ['EATME_TEST_POSTGRES']))
        seed_catalog(service.db)
        user_id = new_id()
        service.save_profile(user_id, {'name': 'Pantry test', 'adult_confirmed': True}, new_id())
        self.addCleanup(service.delete_account, user_id)
        oil = identifier('food', 'olive-oil')
        service.pantry_action(user_id, {'action': 'set', 'food_ids': [oil], 'expected_version': 0}, new_id())
        self.assertEqual(service.pantry(user_id)['food_ids'], [oil])
        line = service.shopping_action(user_id, {'action': 'add', 'food_id': identifier('food', 'tomato'), 'quantity': '200'}, new_id())
        result = service.shopping_action(user_id, {'action': 'purchase_many', 'items': [{'id': line['id'], 'expected_version': 1}]}, new_id())
        self.assertEqual(result['purchased'][0]['expiry_kind'], 'estimated')
        self.assertEqual(service.export_all(user_id)['pantry']['data'], {'food_ids': [oil]})
