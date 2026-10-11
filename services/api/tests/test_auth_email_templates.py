import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


class AuthEmailTemplateTests(unittest.TestCase):
    def test_required_mobile_auth_templates_are_branded_and_actionable(self):
        for name in ("confirmation", "recovery"):
            with self.subTest(name=name):
                html = (ROOT / "supabase" / "templates" / f"{name}.html").read_text()
                self.assertIn("{{ .ConfirmationURL }}", html)
                self.assertIn("https://eatmeapplication.com/eatme-plus-icon.png", html)
                self.assertIn("EatMe+", html)
                self.assertNotIn("tracking", html.casefold())


if __name__ == "__main__":
    unittest.main()
