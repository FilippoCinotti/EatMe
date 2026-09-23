#!/usr/bin/env python3
"""Generate reviewed canonical nutrition payloads from USDA FoodData Central.

Input:
  data/nutrition/usda_reviewed_mappings.json

Only rows explicitly marked "approved" are emitted. Values come directly from
official USDA CSV releases; no food-family averages are invented. For ml/piece
ingredients, the script requires a defensible conversion (explicit reviewed
override or one inferable from USDA portion weights). Rows lacking that
conversion are reported but not published.
"""
from __future__ import annotations

import csv
import io
import json
import re
import urllib.request
import zipfile
from collections import defaultdict
from decimal import Decimal, InvalidOperation
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAPPINGS = ROOT / "data/nutrition/usda_reviewed_mappings.json"
OUTPUT = ROOT / "data/nutrition/usda_nutrition.generated.json"
MIGRATION = ROOT / "supabase/migrations/202609230010_usda_nutrition.sql"

DATASETS = {
    "Foundation Foods": {
        "release": "2026-04-30",
        "url": "https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_foundation_food_csv_2026-04-30.zip",
    },
    "SR Legacy": {
        "release": "2018-04",
        "url": "https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_sr_legacy_food_csv_2018-04.zip",
    },
}

NUTRIENT_NAMES = {
    "protein": ["Protein"],
    "carbohydrates": ["Carbohydrate, by difference"],
    "fat": ["Total lipid (fat)"],
    "saturated_fat": ["Fatty acids, total saturated"],
    "sugars": ["Sugars, total including NLEA", "Sugars, Total NLEA", "Sugars, total"],
    "fiber": ["Fiber, total dietary"],
    "sodium": ["Sodium, Na"],
}
ENERGY_NAMES = [
    "Energy",
    "Energy (Atwater General Factors)",
    "Energy (Atwater Specific Factors)",
]

TARGET_UNITS = {
    "energy": "kcal",
    "protein": "g",
    "carbohydrates": "g",
    "fat": "g",
    "saturated_fat": "g",
    "sugars": "g",
    "fiber": "g",
    "sodium": "mg",
    "salt": "g",
}

VOLUME_ML = {
    "cup": Decimal("236.588"),
    "tablespoon": Decimal("14.7868"),
    "tbsp": Decimal("14.7868"),
    "teaspoon": Decimal("4.92892"),
    "tsp": Decimal("4.92892"),
    "fluid ounce": Decimal("29.5735"),
    "fl oz": Decimal("29.5735"),
    "ml": Decimal("1"),
    "milliliter": Decimal("1"),
}


def decimal(value):
    try:
        parsed = Decimal(str(value))
    except (InvalidOperation, TypeError, ValueError):
        return None
    if not parsed.is_finite():
        return None
    return parsed


def download(dataset: str) -> zipfile.ZipFile:
    meta = DATASETS[dataset]
    request = urllib.request.Request(
        meta["url"],
        headers={"User-Agent": "EatMe canonical nutrition builder/1.0"},
    )
    with urllib.request.urlopen(request, timeout=90) as response:
        return zipfile.ZipFile(io.BytesIO(response.read()))


def csv_rows(zipped: zipfile.ZipFile, basename: str) -> list[dict]:
    target = next(
        (
            name
            for name in zipped.namelist()
            if name.lower().endswith("/" + basename.lower())
            or name.lower() == basename.lower()
        ),
        None,
    )
    if target is None:
        return []
    with zipped.open(target) as raw:
        stream = io.TextIOWrapper(raw, encoding="latin-1", newline="")
        return list(csv.DictReader(stream))


def normalized_unit(value: str) -> str:
    value = (value or "").strip().casefold()
    aliases = {
        "kcal": "kcal",
        "kj": "kJ",
        "g": "g",
        "mg": "mg",
    }
    return aliases.get(value, value)


def nutrient_catalog(zipped: zipfile.ZipFile) -> dict[str, dict]:
    return {row["id"]: row for row in csv_rows(zipped, "nutrient.csv")}


def nutrition_for(
    fdc_id: str,
    nutrients: dict[str, dict],
    food_nutrients: list[dict],
) -> dict:
    rows = [row for row in food_nutrients if row.get("fdc_id") == fdc_id]
    by_name: dict[str, list[tuple[dict, Decimal]]] = defaultdict(list)
    for row in rows:
        nutrient = nutrients.get(row.get("nutrient_id", ""))
        amount = decimal(row.get("amount"))
        if not nutrient or amount is None or amount < 0:
            continue
        by_name[nutrient.get("name", "")].append((nutrient, amount))

    values = {}

    energy = None
    for name in ENERGY_NAMES:
        for nutrient, amount in by_name.get(name, []):
            if normalized_unit(nutrient.get("unit_name", "")) == "kcal":
                energy = amount
                break
        if energy is not None:
            break
    if energy is not None:
        values["energy"] = {"value": str(energy), "unit": "kcal"}

    for key, names in NUTRIENT_NAMES.items():
        selected = None
        for name in names:
            entries = by_name.get(name, [])
            if entries:
                selected = entries[0]
                break
        if selected is None:
            continue
        nutrient, amount = selected
        unit = normalized_unit(nutrient.get("unit_name", ""))
        expected = TARGET_UNITS[key]
        if unit != expected:
            continue
        values[key] = {"value": str(amount), "unit": expected}

    # Salt is a display derivation from USDA sodium: salt ~= sodium * 2.5.
    # Sodium remains the source measurement and the derived flag is explicit.
    if "sodium" in values:
        sodium_mg = Decimal(values["sodium"]["value"])
        salt_g = sodium_mg * Decimal("2.5") / Decimal("1000")
        values["salt"] = {
            "value": str(salt_g.normalize()),
            "unit": "g",
            "derived": True,
            "derived_from": "sodium",
        }

    return values


def portion_text(row: dict, units: dict[str, str]) -> str:
    parts = [
        row.get("portion_description") or "",
        row.get("modifier") or "",
        units.get(row.get("measure_unit_id", ""), ""),
    ]
    return " ".join(parts).casefold()


def infer_density(portions: list[dict], measure_units: dict[str, str]):
    estimates = []
    for row in portions:
        grams = decimal(row.get("gram_weight"))
        amount = decimal(row.get("amount"))
        if grams is None or amount is None or grams <= 0 or amount <= 0:
            continue
        text = portion_text(row, measure_units)
        volume = None
        for token, ml in VOLUME_ML.items():
            if re.search(rf"\b{re.escape(token)}s?\b", text):
                volume = amount * ml
                break
        if volume is not None and volume > 0:
            value = grams / volume
            if Decimal("0.5") <= value <= Decimal("2"):
                estimates.append(value)
    if not estimates:
        return None
    estimates.sort()
    return estimates[len(estimates) // 2].quantize(Decimal("0.0001"))


def infer_piece_weight(portions: list[dict], measure_units: dict[str, str], hint: str | None):
    candidates = []
    for row in portions:
        grams = decimal(row.get("gram_weight"))
        amount = decimal(row.get("amount"))
        if grams is None or amount is None or grams <= 0 or amount <= 0:
            continue
        text = portion_text(row, measure_units)
        if hint and hint.casefold() not in text:
            continue
        if any(token in text for token in ("piece", "egg", "pepper", "unit", "item", "large", "medium", "small")):
            candidates.append(grams / amount)
    if not candidates:
        return None
    candidates.sort()
    return candidates[len(candidates) // 2].quantize(Decimal("0.01"))


def sql_literal(value: dict) -> str:
    return json.dumps(value, separators=(",", ":"), ensure_ascii=False).replace("'", "''")


def scaled_values(values: dict, factor: Decimal) -> dict:
    scaled = {}
    for name, item in values.items():
        amount = decimal(item.get("value"))
        if amount is None:
            continue
        value = (amount * factor).quantize(Decimal("0.000001")).normalize()
        scaled[name] = {**item, "value": str(value)}
        if factor != 1:
            scaled[name]["basis_converted"] = True
    return scaled


def main():
    mappings = json.loads(MAPPINGS.read_text(encoding="utf-8"))
    approved = [row for row in mappings["mappings"] if row.get("status") == "approved"]
    requested = {row["dataset"] for row in approved}
    # April 2026 Foundation contains the current supporting nutrient and measure
    # tables. Older SR Legacy archives can omit those supporting files.
    requested.add("Foundation Foods")
    archives = {dataset: download(dataset) for dataset in requested}
    support_nutrients = nutrient_catalog(archives["Foundation Foods"])
    support_measure_units = {
        row["id"]: row.get("name", "")
        for row in csv_rows(archives["Foundation Foods"], "measure_unit.csv")
    }

    parsed = {}
    for dataset, archive in archives.items():
        local_nutrients = nutrient_catalog(archive)
        local_measure_units = {
            row["id"]: row.get("name", "")
            for row in csv_rows(archive, "measure_unit.csv")
        }
        parsed[dataset] = {
            "nutrients": local_nutrients or support_nutrients,
            "food_nutrients": csv_rows(archive, "food_nutrient.csv"),
            "portions": csv_rows(archive, "food_portion.csv"),
            "measure_units": local_measure_units or support_measure_units,
        }

    output, skipped = [], []
    for row in approved:
        data = parsed[row["dataset"]]
        fdc_id = str(row["fdc_id"])
        values = nutrition_for(fdc_id, data["nutrients"], data["food_nutrients"])
        if not values:
            skipped.append({**row, "reason": "no_supported_nutrients"})
            continue

        portions = [p for p in data["portions"] if p.get("fdc_id") == fdc_id]
        nutrition = {
            "basis": "100g",
            "values": values,
            "source": "USDA FoodData Central",
            "source_url": f"https://fdc.nal.usda.gov/fdc-app.html#/food-details/{fdc_id}/nutrients",
            "source_dataset": row["dataset"],
            "source_release": DATASETS[row["dataset"]]["release"],
            "source_id": fdc_id,
            "source_basis": "100g",
            "match_quality": row.get("match_quality", "reviewed"),
            "reviewed": True,
            "estimated": False,
        }

        # Normalize published values to EatMe's canonical quantity unit so the
        # data is backward-compatible with deployed recipe calculators.
        unit = row["unit"]
        if unit == "ml":
            density = decimal(row.get("density_g_per_ml"))
            if density is None:
                density = infer_density(portions, data["measure_units"])
            if density is None:
                skipped.append({**row, "reason": "density_required"})
                continue
            nutrition["basis"] = "100ml"
            nutrition["values"] = scaled_values(values, density)
            nutrition["density_g_per_ml"] = str(density)
            nutrition["conversion_method"] = "usda_portion_density"
        elif unit == "pcs":
            grams = decimal(row.get("grams_per_piece"))
            if grams is None:
                grams = infer_piece_weight(
                    portions,
                    data["measure_units"],
                    row.get("piece_hint"),
                )
            if grams is None:
                skipped.append({**row, "reason": "piece_weight_required"})
                continue
            nutrition["basis"] = "1pcs"
            nutrition["values"] = scaled_values(values, grams / Decimal("100"))
            nutrition["grams_per_piece"] = str(grams)
            nutrition["conversion_method"] = "usda_portion_piece_weight"

        output.append(
            {
                "id": row["id"],
                "slug": row["slug"],
                "nutrition": nutrition,
            }
        )

    OUTPUT.write_text(
        json.dumps(
            {
                "generated_at": "2026-09-23",
                "source": "USDA FoodData Central",
                "items": output,
                "skipped": skipped,
            },
            indent=2,
            ensure_ascii=False,
        )
        + "\n",
        encoding="utf-8",
    )

    statements = [
        "-- Generated by scripts/build_usda_nutrition_seed.py",
        "-- Source-backed canonical nutrition only; no food-family averages.",
        "BEGIN;",
    ]
    for item in output:
        payload = sql_literal(item["nutrition"])
        statements.append(
            "UPDATE foods SET data = jsonb_set(data::jsonb, '{nutrition}', "
            f"'{payload}'::jsonb, true)::text WHERE id = '{item['id']}';"
        )
    statements += ["COMMIT;", ""]
    MIGRATION.write_text("\n".join(statements), encoding="utf-8")

    print(
        json.dumps(
            {
                "approved": len(approved),
                "generated": len(output),
                "skipped": len(skipped),
            }
        )
    )


if __name__ == "__main__":
    main()
