#!/usr/bin/env python3
"""Validate locale JSON shape and the frozen release-critical key contract."""

from __future__ import annotations

import argparse
import json
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


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    failures = []
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
    if failures:
        raise SystemExit("\n".join(failures))
    print("Localization release contract passed for en, it, es, fr, de and zh-Hans")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
