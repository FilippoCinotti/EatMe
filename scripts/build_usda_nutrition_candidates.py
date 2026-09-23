#!/usr/bin/env python3
"""Build a review-only USDA FoodData Central candidate report.

This script deliberately does not write nutrition values into EatMe catalog data.
It downloads official USDA Foundation Foods (preferred) and SR Legacy (fallback),
matches each current canonical ingredient to likely source foods, and emits a
review artifact. A human-reviewed mapping is required before values can be
published to production.
"""
from __future__ import annotations

import csv
import io
import json
import re
import sys
import urllib.request
import zipfile
from difflib import SequenceMatcher
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGETS = ROOT / "data/nutrition/production_targets.json"
OUTPUT = ROOT / "data/nutrition/usda_candidates.generated.json"

DATASETS = [
    {
        "name": "Foundation Foods",
        "release": "2026-04-30",
        "url": "https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_foundation_food_csv_2026-04-30.zip",
        "priority": 2,
    },
    {
        "name": "SR Legacy",
        "release": "2018-04",
        "url": "https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_sr_legacy_food_csv_2018-04.zip",
        "priority": 1,
    },
]

# Search terms only. These do not assert nutritional equivalence.
# Tricky regional/specialty foods stay review-required even when a close proxy appears.
OVERRIDES = {
    "barbecue-sauce": {"query": "barbecue sauce"},
    "carrot": {"query": "carrots raw"},
    "leek": {"query": "leeks raw"},
    "lime": {"query": "limes raw"},
    "onion": {"query": "onions raw"},
    "potato": {"query": "potatoes raw flesh skin"},
    "spinach": {"query": "spinach raw"},
    "bay-leaf": {"query": "bay leaf"},
    "beef-bones": {"query": "beef bones", "review": "manual"},
    "beef-marrow": {"query": "beef bone marrow", "review": "manual"},
    "borlotti-beans": {"query": "cranberry roman beans cooked", "review": "manual"},
    "breadcrumbs": {"query": "bread crumbs dry"},
    "brown-sugar": {"query": "sugars brown"},
    "cherry-tomato": {"query": "tomatoes red ripe raw"},
    "chicken": {"query": "chicken broilers fryers breast meat only raw"},
    "chicken-thigh": {"query": "chicken thigh meat only raw"},
    "coconut-milk": {"query": "coconut milk"},
    "coriander-seeds": {"query": "coriander seed"},
    "ditaloni-rigati": {"query": "pasta dry unenriched", "review": "proxy"},
    "egg": {"query": "egg whole raw fresh"},
    "egg-yolk": {"query": "egg yolk raw fresh"},
    "flour-00": {"query": "wheat flour white all purpose", "review": "proxy"},
    "fresh-chili": {"query": "peppers hot chili green raw"},
    "fresh-coriander": {"query": "cilantro raw"},
    "fresh-pancetta": {"query": "pork cured bacon raw", "review": "proxy"},
    "fresh-tomato": {"query": "tomatoes red ripe raw"},
    "garam-masala": {"query": "garam masala", "review": "manual"},
    "grana-padano": {"query": "parmesan cheese", "review": "proxy"},
    "greek-yogurt": {"query": "yogurt greek plain"},
    "green-beans": {"query": "beans snap green raw"},
    "green-olives": {"query": "olives ripe canned"},
    "ground-beef": {"query": "beef ground raw"},
    "guanciale": {"query": "pork jowl cured", "review": "manual"},
    "heavy-cream": {"query": "cream fluid heavy whipping"},
    "jasmine-rice": {"query": "rice white long grain raw", "review": "proxy"},
    "kidney-bean": {"query": "beans kidney cooked boiled"},
    "mayonnaise": {"query": "mayonnaise regular"},
    "mozzarella": {"query": "mozzarella cheese whole milk"},
    "olive-oil": {"query": "oil olive salad cooking"},
    "parmesan": {"query": "parmesan cheese"},
    "pasta": {"query": "pasta dry unenriched"},
    "pecorino-romano": {"query": "romano cheese"},
    "peeled-tomatoes": {"query": "tomatoes canned whole"},
    "plain-yogurt": {"query": "yogurt plain whole milk"},
    "prosciutto": {"query": "prosciutto", "review": "manual"},
    "red-bell-pepper": {"query": "peppers sweet red raw"},
    "red-wine": {"query": "alcoholic beverage wine table red"},
    "rice": {"query": "rice white medium grain raw"},
    "ricotta-salata": {"query": "ricotta cheese whole milk", "review": "proxy"},
    "salmon": {"query": "salmon atlantic farmed raw"},
    "sausage": {"query": "sausage italian pork raw", "review": "manual"},
    "smoked-paprika": {"query": "paprika", "review": "proxy"},
    "sour-cream": {"query": "sour cream cultured"},
    "soy-sauce": {"query": "soy sauce made from soy wheat"},
    "spaghetti": {"query": "spaghetti dry unenriched"},
    "spring-onion": {"query": "onions spring scallions raw"},
    "stale-bread": {"query": "bread white commercially prepared", "review": "proxy"},
    "sunflower-oil": {"query": "oil sunflower high linoleic"},
    "tomato-passata": {"query": "tomato puree canned", "review": "proxy"},
    "tomato-paste": {"query": "tomato products canned paste"},
    "tortilla": {"query": "tortilla flour"},
    "vegetable-broth": {"query": "soup vegetable broth"},
    "water": {"query": "water bottled generic"},
    "wheat-flour": {"query": "wheat flour white all purpose"},
    "white-wine": {"query": "alcoholic beverage wine table white"},
    "white-wine-vinegar": {"query": "vinegar distilled", "review": "proxy"},
    "worcestershire-sauce": {"query": "worcestershire sauce"},
}


def normalize(value: str) -> str:
    value = value.casefold().replace("&", " and ")
    value = re.sub(r"[^a-z0-9]+", " ", value)
    return re.sub(r"\s+", " ", value).strip()


def tokens(value: str) -> set[str]:
    stop = {"and", "or", "with", "without", "the", "style", "prepared"}
    return {token for token in normalize(value).split() if token not in stop}


def fetch_food_rows(dataset: dict) -> list[dict]:
    request = urllib.request.Request(
        dataset["url"],
        headers={"User-Agent": "EatMe nutrition catalog builder/1.0"},
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        archive = response.read()
    with zipfile.ZipFile(io.BytesIO(archive)) as zipped:
        name = next(
            (
                item
                for item in zipped.namelist()
                if item.lower().endswith("/food.csv") or item.lower() == "food.csv"
            ),
            None,
        )
        if name is None:
            raise RuntimeError(f"food.csv missing from {dataset['name']}")
        with zipped.open(name) as raw:
            text = io.TextIOWrapper(raw, encoding="latin-1", newline="")
            rows = list(csv.DictReader(text))
    return [
        {
            "fdc_id": row["fdc_id"],
            "description": row["description"],
            "data_type": row.get("data_type") or dataset["name"],
            "dataset": dataset["name"],
            "release": dataset["release"],
            "priority": dataset["priority"],
        }
        for row in rows
        if row.get("fdc_id") and row.get("description")
    ]


def score(query: str, candidate: dict) -> float:
    q = normalize(query)
    d = normalize(candidate["description"])
    qt, dt = tokens(q), tokens(d)
    if not qt:
        return 0.0
    overlap = len(qt & dt) / len(qt)
    precision = len(qt & dt) / max(1, len(dt))
    sequence = SequenceMatcher(None, q, d).ratio()
    starts = 1.0 if d.startswith(q) else 0.0
    foundation_bonus = 0.025 * candidate["priority"]
    return round(
        0.58 * overlap
        + 0.15 * precision
        + 0.22 * sequence
        + 0.03 * starts
        + foundation_bonus,
        6,
    )


def source_url(fdc_id: str) -> str:
    return f"https://fdc.nal.usda.gov/fdc-app.html#/food-details/{fdc_id}/nutrients"


def main() -> int:
    targets = json.loads(TARGETS.read_text(encoding="utf-8"))["foods"]
    candidates: list[dict] = []
    for dataset in DATASETS:
        print(f"Downloading {dataset['name']} {dataset['release']}...", file=sys.stderr)
        candidates.extend(fetch_food_rows(dataset))
    report = []
    for target in targets:
        override = OVERRIDES.get(target["slug"], {})
        query = override.get("query") or target["slug"].replace("-", " ")
        ranked = sorted(
            candidates,
            key=lambda item: score(query, item),
            reverse=True,
        )[:6]
        report.append(
            {
                **target,
                "query": query,
                "review": override.get("review", "required"),
                "candidates": [
                    {
                        "fdc_id": item["fdc_id"],
                        "description": item["description"],
                        "dataset": item["dataset"],
                        "release": item["release"],
                        "score": score(query, item),
                        "source_url": source_url(item["fdc_id"]),
                    }
                    for item in ranked
                ],
            }
        )
    OUTPUT.write_text(
        json.dumps(
            {
                "generated_at": "2026-09-23",
                "source": "USDA FoodData Central",
                "source_page": "https://fdc.nal.usda.gov/download-datasets/",
                "policy": "review-only; no candidate is published automatically",
                "targets": report,
            },
            indent=2,
            ensure_ascii=False,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"Wrote {OUTPUT}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
