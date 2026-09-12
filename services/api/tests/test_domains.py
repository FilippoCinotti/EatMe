import tempfile
import unittest
from datetime import date

from eatme.catalog import identifier, seed_catalog
from eatme.errors import DomainError
from eatme.service import HEALTH_CONSENT, Service, new_id
from eatme.storage import Database


class DomainCase(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.db = Database(self.temp.name + '/app.db')
        self.db.migrate_local()
        seed_catalog(self.db)
        self.app = Service(self.db, clock=lambda: date(2026, 9, 11))
        self.owner, self.guest = new_id(), new_id()
        for uid in (self.owner, self.guest):
            self.app.save_profile(uid, {'name': 'Diner', 'adult_confirmed': True}, new_id())

    def assertCode(self, code, call):
        with self.assertRaises(DomainError) as error:
            call()
        self.assertEqual(error.exception.code, code)

    def join(self, role='member'):
        invite = self.app.household_action(self.owner, {'action': 'invite', 'role': role}, new_id())
        self.app.household_action(self.guest, {'action': 'accept', 'token': invite['token']}, new_id())
        return invite

    def meal(self, slug='sunny-bowl'):
        return {'recipe_id': identifier('recipe', slug), 'servings': 2, 'date': '2026-09-11', 'slot': 'dinner'}

    def test_deletion_tombstone_blocks_access_and_new_members(self):
        invite = self.app.household_action(self.owner, {'action': 'invite'}, new_id())
        with self.db.transaction() as tx:
            tx.execute("INSERT INTO account_deletions VALUES (?,'pending','2026-09-11',NULL,NULL)", (self.owner,))
        self.assertCode('account_deletion_pending', lambda: self.app.get_profile(self.owner))
        self.assertCode('account_deletion_pending', lambda: self.app.save_profile(self.owner, {'name': 'Back', 'adult_confirmed': True}, new_id()))
        self.assertCode('invitation_unavailable', lambda: self.app.household_action(self.guest, {'action': 'accept', 'token': invite['token']}, new_id()))
        self.app.retry_account_deletions()
        with self.db.transaction() as tx:
            self.assertEqual(tx.one('SELECT status FROM account_deletions WHERE user_id=?', (self.owner,))['status'], 'completed')
            self.assertIsNone(tx.one('SELECT 1 FROM profiles WHERE user_id=?', (self.owner,)))

    def test_invitation_is_single_use_and_viewer_cannot_modify_shared_stock(self):
        invite = self.join('viewer')
        self.assertCode('invitation_unavailable', lambda: self.app.household_action(self.guest, {'action': 'accept', 'token': invite['token']}, new_id()))
        self.assertCode('forbidden', lambda: self.app.shopping_action(self.guest, {'action': 'add', 'label': 'Eggs', 'quantity': '2'}, new_id()))
        self.assertEqual(len(self.app.households(self.owner)['members']), 2)
        self.assertNotIn('settings', self.app.households(self.owner)['members'][0])

    def test_shared_meal_requires_consent_then_blocks_allergy_without_revealing_it(self):
        self.join()
        meal = {**self.meal('tomato-feta'), 'participants': [self.owner, self.guest]}
        command = {'action': 'save', 'start_date': '2026-09-11', 'meals': [meal]}
        self.assertCode('participant_consent_required', lambda: self.app.plan_action(self.owner, command, new_id()))
        profile = self.app.get_profile(self.guest)
        self.app.save_profile(self.guest, {'name': 'Guest', 'adult_confirmed': True, 'expected_version': profile['version'], 'allergies': ['milk'], 'health_consent_version': HEALTH_CONSENT}, new_id())
        self.app.household_action(self.guest, {'action': 'share_constraints', 'enabled': True, 'consent_version': 'household-constraints-1'}, new_id())
        self.assertCode('recipe_not_compatible', lambda: self.app.plan_action(self.owner, command, new_id()))

    def test_invitation_listing_is_owner_only_and_revocation_prevents_joining(self):
        self.join()
        invite = self.app.household_action(self.owner, {'action': 'invite'}, new_id())
        listed = self.app.households(self.owner)['invitations']
        self.assertEqual([row['id'] for row in listed], [invite['id']])
        self.assertNotIn('token_hash', listed[0])
        self.assertEqual(self.app.households(self.guest)['invitations'], [])
        self.app.household_action(self.owner, {'action': 'revoke', 'invitation_id': invite['id']}, new_id())
        self.assertCode('invitation_unavailable', lambda: self.app.household_action(self.guest, {'action': 'accept', 'token': invite['token']}, new_id()))

    def test_leaving_restores_personal_home_and_revokes_shared_access(self):
        personal = self.app.get_profile(self.guest)['household_id']
        self.join()
        self.app.household_action(self.guest, {'action': 'share_constraints', 'enabled': True, 'consent_version': 'household-constraints-1'}, new_id())
        self.app.add_inventory(self.owner, {'food_id': identifier('food', 'tomato'), 'quantity': '100'}, new_id())
        key = new_id()
        result = self.app.household_action(self.guest, {'action': 'leave'}, key)
        self.assertEqual(result['household_id'], personal)
        self.assertEqual(result, self.app.household_action(self.guest, {'action': 'leave'}, key))
        self.assertEqual(self.app.inventory(self.guest)['items'], [])
        self.assertEqual(len(self.app.households(self.owner)['members']), 1)
        with self.db.transaction() as tx:
            self.assertIsNone(tx.one('SELECT 1 FROM member_permissions WHERE user_id=?', (self.guest,)))

    def test_plan_shopping_aggregates_stock_once_and_purchase_is_idempotent(self):
        self.app.add_inventory(self.owner, {'food_id': identifier('food', 'tomato'), 'quantity': '100'}, new_id())
        plan = self.app.plan_action(self.owner, {'action': 'save', 'start_date': '2026-09-11', 'meals': [self.meal(), {**self.meal(), 'date': '2026-09-12'}]}, new_id())
        command = {'action': 'generate', 'plan_id': plan['id']}
        self.app.shopping_action(self.owner, command, new_id())
        self.app.shopping_action(self.owner, command, new_id())
        items = self.app.shopping(self.owner)['items']
        self.assertEqual(len(items), 3)
        tomato = next(i for i in items if i['food_id'] == identifier('food', 'tomato'))
        self.assertEqual(tomato['quantity'], '300')
        key, purchase = new_id(), {'action': 'purchase', 'id': tomato['id'], 'expected_version': 1}
        first = self.app.shopping_action(self.owner, purchase, key)
        self.assertEqual(self.app.shopping_action(self.owner, purchase, key), first)
        batches = self.app.inventory(self.owner)['items']
        self.assertEqual(sum(b['quantity_milli'] for b in batches), 400000)
        self.assertCode('shopping_item_not_found', lambda: self.app.shopping_action(self.owner, purchase, new_id()))

    def test_stale_plan_and_shopping_changes_do_not_overwrite(self):
        item = self.app.shopping_action(self.owner, {'action': 'add', 'label': 'Rice', 'quantity': '1'}, new_id())
        update = {'action': 'check', 'id': item['id'], 'expected_version': 1, 'checked': True}
        self.app.shopping_action(self.owner, update, new_id())
        self.assertCode('stale_shopping_item', lambda: self.app.shopping_action(self.owner, update, new_id()))
        plan = self.app.plan_action(self.owner, {'action': 'generate', 'start_date': '2026-09-11'}, new_id())
        self.assertEqual(len(plan['data']['meals']), 7)
        self.assertGreater(len({m['recipe_id'] for m in plan['data']['meals']}), 1)
        self.assertCode('plan_not_found', lambda: self.app.plan_action(self.guest, {'action': 'delete', 'id': plan['id']}, new_id()))

    def test_leftover_remix_consumes_only_additions_and_is_idempotent(self):
        for name in ('chickpea', 'tomato', 'olive-oil'):
            self.app.add_inventory(self.owner, {'food_id': identifier('food', name), 'quantity': '1000'}, new_id())
        meal = self.meal()
        preview = self.app.cooking_preview(self.owner, meal)
        self.app.cooking_confirm(self.owner, {**meal, 'profile_version': preview['profile_version'], 'diet_rules_version': preview['diet_rules_version'], 'batch_versions': {b['batch_id']: b['version'] for b in preview['allocations']}, 'leftover_servings': 1}, new_id())
        leftover = self.app.leftovers(self.owner)['items'][0]
        before = {b['food_id']: b['quantity_milli'] for b in self.app.inventory(self.owner)['items']}
        body = {'action': 'transform_preview', 'id': leftover['id'], 'expected_version': 1, 'servings': 1, 'recipe': {'title': 'Remix', 'servings': 1, 'minutes': 5, 'ingredients': [{'food_id': identifier('food', 'tomato'), 'quantity': '50'}], 'steps': ['Combine the prepared leftovers with the tomatoes.']}}
        plan = self.app.leftover_action(self.owner, body, new_id())
        self.assertEqual(self.app.leftovers(self.owner)['items'][0]['remaining'], 1)
        body.update(action='transform', preparation_confirmed=True, participant_versions=plan['participant_versions'], diet_rules_version=plan['diet_rules_version'], batch_versions={b['batch_id']: b['version'] for b in plan['allocations']})
        key = new_id()
        first = self.app.leftover_action(self.owner, body, key)
        self.assertEqual(first, self.app.leftover_action(self.owner, body, key))
        self.assertEqual(first['remaining'], 0)
        after = {b['food_id']: b['quantity_milli'] for b in self.app.inventory(self.owner)['items']}
        for food_id in before:
            self.assertEqual(before[food_id] - after[food_id], 50000 if food_id == identifier('food', 'tomato') else 0)

    def test_leftovers_cannot_be_consumed_twice_or_after_personal_use_date(self):
        for food, amount in [('tomato', '300'), ('chickpea', '300'), ('olive-oil', '20')]:
            self.app.add_inventory(self.owner, {'food_id': identifier('food', food), 'quantity': amount}, new_id())
        preview = self.app.cooking_preview(self.owner, self.meal())
        command = {**self.meal(), 'profile_version': preview['profile_version'], 'diet_rules_version': preview['diet_rules_version'], 'batch_versions': {b['batch_id']: b['version'] for b in preview['allocations']}, 'leftover_servings': 1, 'leftover_use_date': '2026-09-10'}
        self.app.cooking_confirm(self.owner, command, new_id())
        leftover = self.app.leftovers(self.owner)['items'][0]
        eat = {'action': 'consume', 'id': leftover['id'], 'servings': 1, 'expected_version': 1}
        self.assertCode('leftover_date_passed', lambda: self.app.leftover_action(self.owner, eat, new_id()))
        self.app.leftover_action(self.owner, {**eat, 'action': 'discard'}, new_id())
        self.assertCode('insufficient_leftovers', lambda: self.app.leftover_action(self.owner, {**eat, 'action': 'discard', 'expected_version': 2}, new_id()))
