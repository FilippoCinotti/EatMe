#!/usr/bin/env python3
"""Build the machine-readable screenshot inventory from real PNG renders."""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path


ROUTES = {
    "native-splash-reference": "/launch (native reference)",
    "welcome": "/launch",
    "login": "/login",
    "sign-up": "/login?mode=signup",
    "onboarding-allergies": "/onboarding#allergies",
    "onboarding-eating-style": "/onboarding#eating-style",
    "onboarding-meal-timing": "/onboarding#meal-timing",
    "onboarding-medical": "/onboarding#medical",
    "onboarding-sensitivities": "/onboarding#sensitivities",
    "chef": "/chef",
    "guilty-pleasure-active": "/chef?mode=guilty_pleasure",
    "guilty-pleasure-sheet": "/chef#GuiltyPleasureSheet",
    "fridge": "/fridge",
    "filters": "/fridge#filters",
    "photo-acquisition": "/scanning?mode=photo",
    "custom-food": "/custom-food",
    "plan": "/plan",
    "shopping": "/plan/shopping",
    "profile": "/profile",
    "diet-health": "/diet-health",
    "diet-health-hub": "/diet-health",
    "diet-health-eating-style": "/diet-health#eating-style",
    "diet-health-allergies": "/diet-health#allergies",
    "diet-health-sensitivities": "/diet-health#intolerances",
    "diet-health-medical": "/diet-health#medical",
    "diet-health-therapeutic": "/diet-health#therapeutic",
    "diet-health-ethical": "/diet-health#ethical",
    "diet-health-meal-timing": "/diet-health#meal-timing",
    "diet-health-exclusions": "/diet-health#always-exclude",
    "diet-health-unknown-policy": "/diet-health#unknown-policy",
    "household": "/household",
    "preferences": "/preferences",
    "notifications": "/notifications",
    "privacy": "/privacy",
    "wellbeing": "/wellbeing",
    "recipe": "/recipes/:id",
    "recipe-library-entry": "/recipe-library",
    "recipe-library-imported": "/recipe-library?state=imported",
    "add-ingredient": "/recipe-editor#ingredients",
    "add-methods": "/recipe-editor#method",
    "import-recipe": "/recipe-import",
    "import-processing": "/recipe-import#processing",
    "import-review": "/recipe-import#review",
    "ingredient-mapping": "/recipe-import#mapping",
    "imported-final-recipe": "/recipe-import#saved",
    "imported-final-cook-now": "/recipe-import#cook-now",
    "compatibility-fit": "/recipes/:id#diet-fit-compatible",
    "compatibility-conflict": "/recipes/:id#diet-fit-conflict",
    "suggested-substitutions": "/recipes/:id#substitutions",
    "substitution-selection": "/recipes/:id#substitution-selection",
    "rechecking-adapted": "/recipes/:id#recheck",
    "adapted-success": "/recipes/:id#adapted",
    "no-valid-substitution": "/recipes/:id#no-substitution",
    "eatme-plus": "/subscriptions",
    "eatme-plus-pricing": "/subscriptions#offering",
    "contextual-smart-import-paywall": "/recipe-import#paywall",
    "estimated-savings": "/subscriptions#estimated-savings",
}


def split_name(path: Path) -> tuple[str, str]:
    stem = path.stem
    for theme in ("light", "dark"):
        suffix = f"-{theme}"
        if stem.endswith(suffix):
            return stem[: -len(suffix)], theme
    return stem, "light"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default="docs/screenshots")
    parser.add_argument("--commit", default="unknown")
    args = parser.parse_args()
    root = Path(args.root)
    images = sorted(root.rglob("*.png"))
    entries = []
    for image in images:
        screen_id, theme = split_name(image)
        parts = image.relative_to(root).parts
        platform = parts[0] if parts else "mobile"
        locale = next((part for part in parts if part in {"en", "it", "es", "fr", "de", "zh-Hans"}), "en")
        entries.append(
            {
                "screen_id": screen_id,
                "screen_name": screen_id.replace("-", " ").title(),
                "platform": platform,
                "route_or_fixture": ROUTES.get(screen_id, f"fixture:{screen_id}"),
                "theme": theme,
                "locale": locale,
                "required_state": screen_id,
                "generated_filename": image.as_posix(),
                "real_render": True,
            }
        )
    output = {
        "schema_version": 1,
        "source_commit": args.commit,
        "render_inventory_updated_at": datetime.now(timezone.utc).isoformat(),
        "count": len(entries),
        "screenshots": entries,
    }
    (root / "manifest.json").write_text(json.dumps(output, indent=2) + "\n")
    print(f"Wrote {len(entries)} entries to {root / 'manifest.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
