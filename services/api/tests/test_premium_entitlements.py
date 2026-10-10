"""Paid access follows server-verified RevenueCat entitlements, including restores."""
import tempfile
import unittest
from unittest.mock import patch

from eatme.errors import DomainError
from eatme.service import Service, new_id
from eatme.storage import Database


class PremiumEntitlementTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.db = Database(temp.name + '/app.db')
        self.db.migrate_local()
        self.app = Service(self.db)
        self.user = new_id()
        self.app.save_profile(self.user, {'name': 'Diner', 'adult_confirmed': True}, new_id())
        self.secret = patch.dict('os.environ', {'REVENUECAT_SECRET_KEY': 'server-test-fixture'})
        self.secret.start()
        self.addCleanup(self.secret.stop)

    def refresh(self, entitlements):
        response = {'subscriber': {'entitlements': entitlements}}
        with patch('eatme.lifecycle.json_request', return_value=response) as request:
            snapshot = self.app.entitlements(self.user, refresh=True)
        self.assertEqual(request.call_args.args[0], 'https://api.revenuecat.com/v1/subscribers/' + self.user)
        return snapshot

    def test_purchase_and_restore_activate_production_entitlement(self):
        for expiry in ('2099-01-01T00:00:00Z', None):
            with self.subTest(expiry=expiry):
                snapshot = self.refresh({'eatme_premium': {'expires_date': expiry}})
                self.assertEqual(snapshot['tier'], 'eatme_plus')
                self.assertTrue(snapshot['capabilities']['canUseSmartPlanning'])
                self.assertIsNone(snapshot['remaining']['smart_import'])
                self.app.require_capability(self.user, 'canUseSmartPlanning')
                # Other API requests use the same verified persisted snapshot.
                with patch('eatme.lifecycle.json_request') as request:
                    cached = self.app.entitlements(self.user)
                request.assert_not_called()
                self.assertEqual(cached['tier'], 'eatme_plus')

    def test_expiry_or_revocation_removes_paid_access_after_refresh(self):
        for entitlements in ({'eatme_premium': {'expires_date': '2000-01-01T00:00:00Z'}}, {}):
            with self.subTest(entitlements=entitlements):
                self.refresh({'eatme_premium': {'expires_date': None}})
                snapshot = self.refresh(entitlements)
                self.assertEqual(snapshot['tier'], 'free')
                self.assertFalse(snapshot['capabilities']['canUseSmartPlanning'])
                self.assertTrue(snapshot['capabilities']['canSeeSafetyWarnings'])
                with self.assertRaises(DomainError):
                    self.app.require_capability(self.user, 'canUseSmartPlanning')

    def test_legacy_identifiers_still_work(self):
        for name in ('eatme_plus', 'premium'):
            with self.subTest(name=name):
                self.assertEqual(self.refresh({name: {'expires_date': None}})['tier'], 'eatme_plus')

    def test_unrelated_entitlement_does_not_grant_premium(self):
        self.assertEqual(self.refresh({'other_product': {'expires_date': None}})['tier'], 'free')
