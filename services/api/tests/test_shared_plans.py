import unittest
import test_domains as support
from eatme.validation import new_id
from eatme.service import HEALTH_CONSENT


class SharedPlansCase(unittest.TestCase):
    setUp = support.DomainCase.setUp
    join = support.DomainCase.join
    meal = support.DomainCase.meal
    assertCode = support.DomainCase.assertCode

    def plan(self):
        return self.app.plan_action(self.owner, {'action': 'save', 'start_date': '2026-09-11', 'meals': [self.meal()]}, new_id())

    def test_explicit_sharing_preserves_privacy_and_concurrent_versions(self):
        self.join()
        plan = self.plan()
        self.assertEqual(self.app.plans(self.guest)['items'], [])
        shared = self.app.plan_action(self.owner, {'action': 'set_visibility', 'id': plan['id'], 'expected_version': 1, 'shared': True}, new_id())
        self.assertEqual(len(self.app.plans(self.guest)['items']), 1)
        self.assertEqual(shared['data']['meals'][0]['participants'], [self.owner])
        profile = self.app.get_profile(self.owner)
        self.app.save_profile(self.owner, {'name': 'Owner', 'adult_confirmed': True, 'expected_version': profile['version'], 'health_consent_version': HEALTH_CONSENT}, new_id())
        self.app.household_action(self.owner, {'action': 'share_constraints', 'enabled': True, 'consent_version': 'household-constraints-1'}, new_id())
        locked = self.app.plan_action(self.guest, {'action': 'lock', 'id': plan['id'], 'date': '2026-09-11', 'slot': 'dinner', 'expected_version': shared['version'], 'locked': True}, new_id())
        self.assertEqual(locked['version'], 3)
        self.assertCode('stale_plan', lambda: self.app.plan_action(self.owner, {'action': 'set_visibility', 'id': plan['id'], 'expected_version': 2, 'shared': False}, new_id()))
        self.assertCode('forbidden', lambda: self.app.plan_action(self.guest, {'action': 'set_visibility', 'id': plan['id'], 'expected_version': 3, 'shared': False}, new_id()))

    def test_viewer_can_read_shared_plan_but_cannot_edit(self):
        self.join('viewer')
        plan = self.plan()
        self.app.plan_action(self.owner, {'action': 'set_visibility', 'id': plan['id'], 'expected_version': 1, 'shared': True}, new_id())
        self.assertEqual(len(self.app.plans(self.guest)['items']), 1)
        self.assertCode('forbidden', lambda: self.app.plan_action(self.guest, {'action': 'delete', 'id': plan['id'], 'expected_version': 2}, new_id()))
        self.app.household_action(self.guest, {'action': 'leave'}, new_id())
        self.assertEqual(self.app.plans(self.guest)['items'], [])


if __name__ == '__main__':
    unittest.main()
