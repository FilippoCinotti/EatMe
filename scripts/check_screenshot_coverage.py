#!/usr/bin/env python3
"""Fail when screenshot policy, manifest, or generated files drift."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


def mobile_routes(source: str) -> set[str]:
    routes = set(re.findall(r"path:\s*'([^']+)'", source))
    redirects = set(re.findall(r"GoRoute\(path:\s*'([^']+)'\s*,\s*redirect:", source))
    return routes - redirects - {"/login-callback"}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", default="docs/screenshots/manifest.json")
    parser.add_argument("--policy", default="docs/screenshots/required_screens.json")
    parser.add_argument("--mobile-routes", default="apps/mobile/lib/main.dart")
    parser.add_argument("--require-files", action="store_true")
    parser.add_argument("--routes-only", action="store_true")
    args = parser.parse_args()
    manifest_path = Path(args.manifest)
    policy = json.loads(Path(args.policy).read_text())
    manifest = json.loads(manifest_path.read_text())
    failures: list[str] = []
    declared_routes = set(policy["mobile_route_coverage"])
    source_routes = mobile_routes(Path(args.mobile_routes).read_text())
    missing_routes = sorted(source_routes - declared_routes)
    stale_routes = sorted(declared_routes - source_routes)
    if missing_routes:
        failures.append(f"Production mobile routes missing policy entries: {missing_routes}")
    if stale_routes:
        failures.append(f"Screenshot policy contains stale mobile routes: {stale_routes}")
    if args.routes_only:
        if failures:
            print("Screenshot route coverage failed:")
            for failure in failures:
                print(f"- {failure}")
            return 1
        print(f"Screenshot policy covers all {len(source_routes)} production mobile routes")
        return 0
    keys = {
        (item["screen_id"], item["platform"], item["locale"], item["theme"])
        for item in manifest["screenshots"]
    }
    required_renders = list(policy.get("required_renders", []))
    for screen_id in policy.get("mobile_english_light_dark", []):
        for theme in ("light", "dark"):
            required_renders.append(
                {"screen_id": screen_id, "platform": "mobile", "locale": "en", "theme": theme}
            )
    for screen_id in policy.get("guest_english_light_dark", []):
        for theme in ("light", "dark"):
            required_renders.append(
                {"screen_id": screen_id, "platform": "guest", "locale": "en", "theme": theme}
            )
    for required in required_renders:
        key = (required["screen_id"], required["platform"], required["locale"], required["theme"])
        if key not in keys:
            failures.append(f"Missing manifest render: {key}")
    if args.require_files:
        for item in manifest["screenshots"]:
            if not Path(item["generated_filename"]).is_file():
                failures.append(f"Missing screenshot file: {item['generated_filename']}")
    if failures:
        print("Screenshot coverage failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1
    print(f"Screenshot coverage passed: {len(manifest['screenshots'])} real renders inventoried")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
