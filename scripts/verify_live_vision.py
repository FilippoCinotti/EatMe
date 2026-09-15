#!/usr/bin/env python3
"""Run EatMe's real two-image vision acceptance path.

This script deliberately refuses fixture mode. It exercises the same private
media, durable job, structured validation, review payload and atomic inventory
confirmation code used by the mobile application.
"""
from __future__ import annotations

import argparse
import base64
import json
import os
import sys
import tempfile
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "services" / "api"))

from eatme.catalog import seed_catalog  # noqa: E402
from eatme.service import Service, new_id  # noqa: E402
from eatme.storage import Database  # noqa: E402


def fail(message: str) -> None:
    raise SystemExit("LIVE VISION ACCEPTANCE FAILED: " + message)


def process(service: Service, user: str, path: Path) -> dict:
    media = service.media_upload(
        user,
        {"kind": "photo", "base64": base64.b64encode(path.read_bytes()).decode()},
    )
    job = service.job_action(
        user,
        {"action": "create", "kind": "photo", "media_id": media["id"]},
        new_id(),
    )
    if service.run_next_job() is not True:
        fail(f"worker did not lease {path.name}")
    stored = next(
        item for item in service.jobs(user)["items"] if item["id"] == job["id"]
    )
    if stored["status"] != "completed":
        fail(f"{path.name} ended as {stored['status']}: {stored.get('error_code')}")
    result = stored["result"]
    if result.get("development_fixture") is not False:
        fail("provider result is not explicitly live")
    if not result.get("items"):
        fail(f"{path.name} produced no reviewable detections")

    confirmed = []
    for item in result["items"]:
        if item.get("food_id") and item.get("quantity"):
            confirmed.append(
                {
                    "food_id": item["food_id"],
                    "quantity": item["quantity"],
                    "location": "fridge",
                    "expiry_date": None,
                    "expiry_kind": "unknown",
                    "confirmed": True,
                }
            )
    if not confirmed:
        fail(f"{path.name} has no canonical detection with a reviewable quantity")
    saved = service.job_action(
        user,
        {"action": "confirm", "id": job["id"], "items": confirmed},
        new_id(),
    )
    if len(saved["ids"]) != len(confirmed):
        fail(f"{path.name} was not atomically confirmed into inventory")
    return {
        "image": path.name,
        "job_id": job["id"],
        "detections": result["items"],
        "inventory_ids": saved["ids"],
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("first", type=Path)
    parser.add_argument("second", type=Path)
    args = parser.parse_args()

    if os.getenv("AI_PROVIDER") != "openai":
        fail("set AI_PROVIDER=openai; fixture and unset modes never count")
    if not os.getenv("AI_API_KEY") or not os.getenv("AI_MODEL"):
        fail("AI_API_KEY and AI_MODEL are required")
    for path in (args.first, args.second):
        if not path.is_file():
            fail(f"missing image: {path}")
        if path.resolve() == args.first.resolve() == args.second.resolve():
            fail("provide two different image files")

    with tempfile.TemporaryDirectory(prefix="eatme-live-vision-") as temporary:
        os.environ["EATME_ENV"] = "development"
        os.environ["MEDIA_DIRECTORY"] = str(Path(temporary) / "media")
        database = Database(str(Path(temporary) / "eatme.sqlite3"))
        database.migrate_local()
        seed_catalog(database)
        service = Service(database, clock=lambda: date.today())
        user = new_id()
        service.save_profile(
            user,
            {
                "name": "Live vision acceptance",
                "adult_confirmed": True,
                "household_size": 1,
                "diets": [],
            },
            new_id(),
        )
        service.preferences(
            user,
            {"expected_version": 0, "data": {"ai_consent": True}},
            new_id(),
        )
        results = [
            process(service, user, args.first),
            process(service, user, args.second),
        ]
        signatures = [
            [
                (item.get("food_id"), item.get("name"))
                for item in result["detections"]
            ]
            for result in results
        ]
        if signatures[0] == signatures[1]:
            fail("the two distinct images produced the same detection signature")
        inventory = service.inventory(user)["items"]
        expected = sum(len(result["inventory_ids"]) for result in results)
        if len(inventory) != expected:
            fail("confirmed detections are not present in inventory")

        print(
            json.dumps(
                {
                    "status": "passed",
                    "provider": "openai",
                    "model": os.environ["AI_MODEL"],
                    "images": results,
                    "inventory_items": len(inventory),
                },
                indent=2,
            )
        )


if __name__ == "__main__":
    main()

