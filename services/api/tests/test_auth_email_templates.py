import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


class AuthEmailTemplateTests(unittest.TestCase):
    def test_required_mobile_auth_templates_are_branded_and_actionable(self):
        for name in ("confirmation", "recovery"):
            with self.subTest(name=name):
                html = (ROOT / "supabase" / "templates" / f"{name}.html").read_text()
                self.assertIn("{{ .ConfirmationURL }}", html)
                self.assertIn("https://eatmeapplication.com/eatme-plus-logo.png", html)
                self.assertNotIn("eatme-plus-icon.png", html)
                self.assertIn("EatMe+", html)
                self.assertNotIn("tracking", html.casefold())

    def test_email_logo_is_a_public_raster_asset(self):
        logo = ROOT / "apps" / "public" / "public" / "eatme-plus-logo.png"
        self.assertTrue(logo.is_file())
        self.assertEqual(logo.read_bytes()[:8], b"\x89PNG\r\n\x1a\n")


if __name__ == "__main__":
    unittest.main()
