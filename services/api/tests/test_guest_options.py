import re
import unittest
from pathlib import Path

from eatme.catalog import ALLERGENS, INTOLERANCES, SENSITIVITIES
from eatme.dinners import EATING_STYLES

OPTIONS = Path(__file__).resolve().parents[3] / "apps" / "guest" / "lib" / "options.ts"
LOCALES = ("en", "it", "es", "fr", "de", '"zh-Hans"')


class GuestOptionLabelsTest(unittest.TestCase):
    def test_every_questionnaire_code_has_a_name_in_every_guest_locale(self):
        source = OPTIONS.read_text()
        entries = dict(re.findall(r'^\s*"?([\w-]+)"?: \{ (en: .*) \},$', source, re.M))
        for code in [*ALLERGENS, *INTOLERANCES, *SENSITIVITIES, *sorted(EATING_STYLES)]:
            with self.subTest(code=code):
                self.assertIn(code, entries)
                for locale in LOCALES:
                    self.assertRegex(entries[code], rf'(^|, ){re.escape(locale)}: "[^"]+"')


if __name__ == "__main__":
    unittest.main()
