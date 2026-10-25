import base64
import io
import unittest
import test_content_jobs as support
from eatme.catalog import identifier
from eatme.validation import new_id


class CaptureDatesCase(unittest.TestCase):
    setUp = support.ContentCase.setUp

    def run_capture(self, evidence):
        self.app.preferences(self.owner, {'expected_version': 0, 'data': {'ai_consent': True}}, new_id())
        class Provider:
            def run(self, *args):
                return {'detected_type': 'food_photo', 'items': [{'food_id': identifier('food', 'tomato'),
                    'name': 'Tomatoes', 'quantity': '500', 'unit': 'g', 'confidence': .8,
                    'expiry_date': '2026-09-15', 'expiry_kind': 'best_before', 'expiry_evidence': evidence}]}
        self.app.ai_provider = Provider()
        from PIL import Image
        buffer = io.BytesIO()
        Image.new('RGB', (200, 200), 'white').save(buffer, format='PNG')
        media = self.app.media_upload(self.owner, {'kind': 'photo', 'base64': base64.b64encode(buffer.getvalue()).decode()})
        created = self.app.job_action(self.owner, {'action': 'create', 'kind': 'auto', 'media_id': media['id']}, new_id())
        self.app.run_next_job()
        return next(j for j in self.app.jobs(self.owner)['items'] if j['id'] == created['id'])

    def test_label_date_remains_unconfirmed_and_inventory_is_unchanged(self):
        job = self.run_capture('Best before 15/09/2026')
        self.assertEqual(job['status'], 'completed')
        item = job['result']['items'][0]
        self.assertEqual(item['expiry_source'], 'label_extraction')
        self.assertTrue(item['requires_confirmation'])
        self.assertEqual(self.app.inventory(self.owner)['items'], [])

    def test_date_without_label_evidence_is_rejected(self):
        job = self.run_capture(None)
        self.assertEqual(job['status'], 'failed')
        self.assertEqual(self.app.inventory(self.owner)['items'], [])


if __name__ == '__main__':
    unittest.main()
