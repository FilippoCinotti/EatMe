import base64
import io
import os
import tempfile
import unittest
from datetime import date
from unittest.mock import patch

from eatme.catalog import identifier, seed_catalog
from eatme.errors import DomainError
from eatme.intelligence import normalize_image
from eatme.providers import barcode, nutrition
from eatme.service import Service, new_id
from eatme.storage import Database


class ContentCase(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.env = patch.dict(os.environ, {'AI_PROVIDER': 'development', 'EATME_ENV': 'development', 'MEDIA_DIRECTORY': self.temp.name + '/media'})
        self.env.start()
        self.addCleanup(self.env.stop)
        self.db = Database(self.temp.name + '/app.db')
        self.db.migrate_local()
        seed_catalog(self.db)
        self.app = Service(self.db, clock=lambda: date(2026, 9, 11))
        self.owner, self.reviewer = new_id(), new_id()
        for uid in (self.owner, self.reviewer):
            self.app.save_profile(uid, {'name': 'Diner', 'adult_confirmed': True}, new_id())

    def assertCode(self, code, call):
        with self.assertRaises(DomainError) as error:
            call()
        self.assertEqual(error.exception.code, code)

    def recipe(self):
        return {'title': 'My bowl', 'minutes': 10, 'servings': 1, 'steps': ['Combine the cooked chickpeas and tomatoes.'], 'ingredients': [{'food_id': identifier('food', 'chickpea'), 'quantity': '100'}, {'food_id': identifier('food', 'tomato'), 'quantity': '100'}]}

    def test_private_recipes_do_not_leak_through_catalog_or_direct_identifier(self):
        saved = self.app.recipe_action(self.owner, {'action': 'save', 'recipe': self.recipe()}, new_id())
        self.assertIn(saved['id'], [r['id'] for r in self.app.recipes(self.owner)['items']])
        self.assertNotIn(saved['id'], [r['id'] for r in self.app.recipes(self.reviewer)['items']])
        self.assertCode('recipe_not_found', lambda: self.app.recipe(self.reviewer, saved['id']))
        self.app.delete_account(self.owner)
        with self.db.transaction() as tx:
            self.assertIsNone(tx.one('SELECT id FROM recipes WHERE id=?', (saved['id'],)))

    def test_unknown_ingredients_cannot_be_saved_and_feedback_is_private(self):
        recipe = self.recipe()
        recipe['ingredients'][0]['food_id'] = new_id()
        self.assertCode('unknown_ingredient', lambda: self.app.recipe_action(self.owner, {'action': 'save', 'recipe': recipe}, new_id()))
        rid = identifier('recipe', 'sunny-bowl')
        self.app.recipe_action(self.owner, {'action': 'favorite', 'recipe_id': rid, 'enabled': True}, new_id())
        self.assertFalse(next(r for r in self.app.recipes(self.reviewer)['items'] if r['id'] == rid)['favorite'])

    def test_archiving_a_cooked_recipe_preserves_history_and_hides_discovery(self):
        recipe = self.app.recipe_action(self.owner, {'action': 'save', 'recipe': self.recipe()}, new_id())
        for ingredient in recipe['ingredients']:
            self.app.add_inventory(self.owner, ingredient, new_id())
        meal = {'recipe_id': recipe['id'], 'servings': 1}
        preview = self.app.cooking_preview(self.owner, meal)
        self.app.cooking_confirm(self.owner, {**meal, 'profile_version': preview['profile_version'],
            'diet_rules_version': preview['diet_rules_version'],
            'batch_versions': {b['batch_id']: b['version'] for b in preview['allocations']}}, new_id())
        self.app.recipe_action(self.owner, {'action': 'delete', 'recipe_id': recipe['id']}, new_id())
        self.assertCode('recipe_not_found', lambda: self.app.recipe(self.owner, recipe['id']))
        self.assertNotIn(recipe['id'], [r['id'] for r in self.app.recipes(self.owner)['items']])
        self.assertEqual(len(self.app.export_all(self.owner)['cooking_sessions']), 1)

    def test_editor_cannot_publish_own_evidence_and_expired_sources_are_excluded(self):
        with patch.dict(os.environ, {'ADMIN_USER_IDS': self.owner + ',' + self.reviewer}):
            draft = self.app.admin_action(self.owner, {'action': 'draft', 'kind': 'evidence', 'data': {'title': 'Synthetic test', 'publisher': 'Test fixture', 'claim': 'Not a real nutrition claim.', 'jurisdiction': 'test', 'strength': 'expert_opinion', 'published_date': '2026-01-01', 'review_due': '2026-09-11', 'url': 'https://example.com/test'}}, new_id())
            self.app.admin_action(self.owner, {'action': 'submit', 'id': draft['id'], 'expected_status': 'DRAFT'}, new_id())
            self.assertCode('independent_review_required', lambda: self.app.admin_action(self.owner, {'action': 'publish', 'id': draft['id'], 'expected_status': 'IN_REVIEW'}, new_id()))
            self.app.admin_action(self.reviewer, {'action': 'publish', 'id': draft['id'], 'expected_status': 'IN_REVIEW'}, new_id())
            self.assertEqual(len(self.app.evidence(self.owner)['items']), 1)
            self.app.clock = lambda: date(2026, 9, 12)
            self.assertEqual(self.app.evidence(self.owner)['items'], [])

    def test_jobs_require_consent_and_confirmation_is_atomic_and_idempotent(self):
        self.assertCode('ai_consent_required', lambda: self.app.job_action(self.owner, {'action': 'create', 'kind': 'recipe'}, new_id()))
        self.app.preferences(self.owner, {'expected_version': 0, 'data': {'ai_consent': True}}, new_id())
        from PIL import Image
        buffer = io.BytesIO()
        Image.new('RGB', (200, 200), 'green').save(buffer, format='PNG')
        media = self.app.media_upload(self.owner, {'kind': 'photo', 'base64': base64.b64encode(buffer.getvalue()).decode()})
        job = self.app.job_action(self.owner, {'action': 'create', 'kind': 'photo', 'media_id': media['id']}, new_id())
        self.assertTrue(self.app.run_next_job())
        result = self.app.jobs(self.owner)['items'][0]
        self.assertEqual(result['status'], 'completed')
        self.assertEqual(self.app.inventory(self.owner)['items'], [])
        self.assertEqual(self.app.jobs(self.reviewer)['items'], [])
        items = result['result']['items']
        self.assertCode('detection_confirmation_required', lambda: self.app.job_action(self.owner, {'action': 'confirm', 'id': job['id'], 'items': items}, new_id()))
        items[0]['confirmed'] = True
        key, body = new_id(), {'action': 'confirm', 'id': job['id'], 'items': items}
        first = self.app.job_action(self.owner, body, key)
        self.assertEqual(first, self.app.job_action(self.owner, body, key))
        self.assertEqual(len(self.app.inventory(self.owner)['items']), 1)

    def test_invalid_ai_output_fails_closed_and_cancelled_job_does_not_run(self):
        self.app.preferences(self.owner, {'expected_version': 0, 'data': {'ai_consent': True}}, new_id())
        job = self.app.job_action(self.owner, {'action': 'create', 'kind': 'recipe'}, new_id())
        class BadProvider:
            def run(self, *args):
                return {'title': 'Ignored schema', 'ingredients': []}
        self.app.ai_provider = BadProvider()
        self.app.run_next_job()
        self.assertEqual(self.app.jobs(self.owner)['items'][0]['status'], 'failed')
        job = self.app.job_action(self.owner, {'action': 'create', 'kind': 'recipe'}, new_id())
        self.app.job_action(self.owner, {'action': 'cancel', 'id': job['id']}, new_id())
        self.assertFalse(self.app.run_next_job())

    def test_media_normalization_removes_metadata_and_preserves_size_bound(self):
        from PIL import Image
        buffer = io.BytesIO()
        img = Image.new('RGB', (400, 300), 'white')
        exif = Image.Exif()
        exif[270] = 'Private metadata'
        img.save(buffer, format='JPEG', exif=exif)
        normalized = normalize_image(buffer.getvalue())
        self.assertEqual(dict(Image.open(io.BytesIO(normalized)).getexif()), {})
        self.assertCode('invalid_image', lambda: normalize_image(b'not an image'))

    def test_product_checksums_and_salt_sodium_conversion(self):
        self.assertEqual(barcode('3017620422003'), '3017620422003')
        self.assertCode('invalid_barcode', lambda: barcode('3017620422004'))
        data = nutrition({'nutriments': {'salt_100g': 1, 'fat_100g': 'NaN'}})
        self.assertEqual(data['values']['sodium']['value'], '0.4')
        self.assertNotIn('fat', data['values'])

    def test_analytics_rejects_health_fields_and_export_includes_preferences(self):
        self.app.preferences(self.owner, {'expected_version': 0, 'data': {'analytics': True}}, new_id())
        self.assertCode('invalid_analytics', lambda: self.app.analytics(self.owner, {'event': 'screen_view', 'data': {'allergy': 'milk'}}))
        self.app.analytics(self.owner, {'event': 'screen_view', 'data': {'screen': 'fridge'}})
        exported = self.app.export_all(self.owner)
        self.assertEqual(len(exported['analytics_events']), 1)
        self.assertEqual(len(exported['user_preferences']), 1)
