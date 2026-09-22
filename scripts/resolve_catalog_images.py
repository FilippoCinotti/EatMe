#!/usr/bin/env python3
import json
import re
import unicodedata
import urllib.request
from pathlib import Path

BASE = "https://huggingface.co/datasets/ionicam/ingredient-atlas/resolve/main"
MANIFEST = f"{BASE}/data/manifest.compact.json"
ROOT = Path(__file__).resolve().parents[1]
TARGETS = ROOT / "scripts" / "catalog_image_targets.json"
OUTPUT = ROOT / "generated" / "catalog_image_map.json"

def norm(value):
    value = unicodedata.normalize("NFKD", str(value or ""))
    value = "".join(ch for ch in value if not unicodedata.combining(ch)).lower()
    value = value.replace("&", " and ")
    value = re.sub(r"[^a-z0-9]+", "-", value).strip("-")
    return re.sub(r"-{2,}", "-", value)

with urllib.request.urlopen(MANIFEST, timeout=60) as response:
    manifest = json.load(response)

records = manifest["recordsBySlug"]
aliases = manifest.get("aliases", {})
targets = json.loads(TARGETS.read_text())

def resolve(value):
    key = norm(value)
    rec = records.get(key) or aliases.get(key)
    if isinstance(rec, str):
        rec = records.get(rec)
    return rec

mapped = []
unmapped = []
for item in targets:
    rec = resolve(item.get("name_en")) or resolve(item.get("slug"))
    if not rec:
        unmapped.append(item)
        continue
    if (rec.get("kind") or "food") != "food":
        unmapped.append(item)
        continue
    image = (rec.get("images") or {}).get("webp512") or (rec.get("images") or {}).get("png512")
    if not image:
        unmapped.append(item)
        continue
    path = image["path"]
    mapped.append({
        "id": item["id"],
        "slug": item["slug"],
        "atlas_slug": rec["slug"],
        "category": rec.get("category"),
        "image_url": BASE.rstrip("/") + "/" + path.lstrip("/"),
        "license": rec.get("license") or "CC0-1.0",
        "source": "ingredient-atlas",
    })

OUTPUT.parent.mkdir(parents=True, exist_ok=True)
OUTPUT.write_text(json.dumps({
    "source": "Ingredient Atlas",
    "source_url": "https://huggingface.co/datasets/ionicam/ingredient-atlas",
    "license": "CC0-1.0",
    "mapped_count": len(mapped),
    "unmapped_count": len(unmapped),
    "mapped": mapped,
    "unmapped": unmapped,
}, indent=2) + "\n")
print(f"mapped={len(mapped)} unmapped={len(unmapped)}")
