#!/usr/bin/env python3
"""Validate locale JSON shape, the release-critical keys and full key parity.

Every locale must translate every key of the canonical English file, with the
same {placeholders}; a missing key would silently fall back to English.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


LOCALES = ("en", "it", "es", "fr", "de", "zh-Hans")
RELEASE_CRITICAL = {
    "eatme",
    "chef_table",
    "fridge",
    "plan",
    "profile",
    "guilty_pleasure",
    "guilty_pleasure_body",
    "guilty_pleasure_safety",
    "this_meal",
    "today",
    "turn_on_guilty_pleasure",
    "turn_off_guilty_pleasure",
    "guilty_pleasure_tonight",
    "cancel",
}


PLACEHOLDER = re.compile(r"\{[A-Za-z_]+\}")


def placeholders(value: str) -> list[str]:
    return sorted(PLACEHOLDER.findall(value))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    failures = []
    canonical = json.loads((args.directory / "en.json").read_text())
    for locale in LOCALES:
        path = args.directory / f"{locale}.json"
        try:
            data = json.loads(path.read_text())
        except (OSError, json.JSONDecodeError) as error:
            failures.append(f"{locale}: invalid or missing JSON ({error})")
            continue
        missing = sorted(RELEASE_CRITICAL - set(data))
        blank = sorted(key for key in RELEASE_CRITICAL & set(data) if not str(data[key]).strip())
        if missing:
            failures.append(f"{locale}: missing release keys {missing}")
        if blank:
            failures.append(f"{locale}: blank release keys {blank}")
        untranslated = sorted(set(canonical) - set(data))
        if untranslated:
            failures.append(f"{locale}: {len(untranslated)} keys missing, e.g. {untranslated[:5]}")
        unknown = sorted(set(data) - set(canonical))
        if unknown:
            failures.append(f"{locale}: keys not in en.json {unknown[:5]}")
        empty = sorted(key for key, value in data.items() if not str(value).strip())
        if empty:
            failures.append(f"{locale}: empty values {empty[:5]}")
        mismatched = sorted(
            key
            for key in set(canonical) & set(data)
            if placeholders(str(canonical[key])) != placeholders(str(data[key]))
        )
        if mismatched:
            failures.append(f"{locale}: placeholder mismatch {mismatched[:5]}")
    if failures:
        raise SystemExit("\n".join(failures))
    print(f"Localization contract passed: {len(canonical)} keys in en, it, es, fr, de and zh-Hans")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
