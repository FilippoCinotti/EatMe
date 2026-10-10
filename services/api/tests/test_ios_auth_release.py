"""Prevent native Apple login failures caused by distribution signing."""
import importlib.util
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


def load_script(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "scripts" / (name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


check = load_script("check_ios_auth_entitlements")
signing = load_script("configure_ios_signing")


class IOSAuthReleaseTests(unittest.TestCase):
    def entitlements(self):
        return {
            "application-identifier": "TESTTEAM.com.filippocinotti.eatme",
            "get-task-allow": False,
            "com.apple.developer.applesignin": ["Default"],
        }

    def test_valid_signed_capabilities(self):
        app = self.entitlements()
        self.assertEqual(check.validate(app, {"Entitlements": dict(app)}, "com.filippocinotti.eatme"), [])

    def test_profile_capability_does_not_replace_signed_app_capability(self):
        app = self.entitlements()
        profile = {"Entitlements": dict(app)}
        del app["com.apple.developer.applesignin"]
        self.assertIn("Signed app is missing the Sign in with Apple entitlement.",
                      check.validate(app, profile, "com.filippocinotti.eatme"))

    def test_mismatched_identity_and_debug_signing_are_rejected(self):
        app = self.entitlements()
        profile = {"Entitlements": dict(app)}
        app["application-identifier"] = "OTHERTEAM.com.filippocinotti.eatme"
        app["get-task-allow"] = True
        self.assertEqual(len(check.validate(app, profile, "com.filippocinotti.eatme")), 2)

    def test_profile_must_allow_native_apple_login(self):
        app = self.entitlements()
        profile = {"Entitlements": dict(app)}
        del profile["Entitlements"]["com.apple.developer.applesignin"]
        self.assertIn("Provisioning profile does not allow Sign in with Apple.",
                      check.validate(app, profile, "com.filippocinotti.eatme"))

    def test_missing_reviewed_settings_and_unsafe_values_are_rejected(self):
        with self.assertRaises(ValueError):
            signing.configure("unreviewed project", "TESTTEAM", "Distribution")
        project = "\n".join([signing.ANCHOR] * 3)
        for value in ('', 'bad"setting', 'bad\nsetting', 'bad;setting'):
            with self.subTest(value=value), self.assertRaises(ValueError):
                signing.configure(project, "TESTTEAM", value)
