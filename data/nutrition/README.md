# Canonical nutrition data

EatMe recipe nutrition is calculated from ingredient quantities. Canonical
ingredient nutrition must therefore be **ingredient-specific and source-backed**.

## Source policy

Primary source: USDA FoodData Central.

- Foundation Foods: April 2026 release, preferred when an appropriate food exists.
- SR Legacy: April 2018, fallback for canonical foods not covered by Foundation.
- Packaged products continue to use product-specific Open Food Facts data and are
  not treated as canonical ingredient nutrition.
- Food-family averages are not permitted as ingredient defaults.
- Regional/specialty foods may use a proxy only after explicit review; the mapping
  must record `match_quality: "proxy"`.
- No mapping is published automatically from fuzzy matching.

FoodData Central publishes downloadable CSV/JSON releases and source metadata:
https://fdc.nal.usda.gov/download-datasets/

## Pipeline

1. `production_targets.json` snapshots canonical ingredients used by eligible
   production recipes.
2. `scripts/build_usda_nutrition_candidates.py` downloads official USDA
   releases and creates a review-only candidate file.
3. A reviewer selects exact/acceptable source foods into
   `usda_reviewed_mappings.json`.
4. `scripts/build_usda_nutrition_seed.py` extracts source nutrients, requires
   density/piece conversions where needed, and generates:
   - `usda_nutrition.generated.json`
   - immutable Supabase migration `202609230010_usda_nutrition.sql`
5. The generated migration is reviewed before it is applied to production.

## Nutrition payload

Canonical nutrition is stored in the existing food JSON:

```json
{
  "basis": "100g",
  "values": {
    "energy": {"value": "18", "unit": "kcal"},
    "protein": {"value": "0.9", "unit": "g"},
    "sodium": {"value": "5", "unit": "mg"}
  },
  "source": "USDA FoodData Central",
  "source_url": "https://fdc.nal.usda.gov/fdc-app.html#/food-details/<id>/nutrients",
  "source_dataset": "Foundation Foods",
  "source_release": "2026-04-30",
  "source_id": "<fdc_id>",
  "match_quality": "exact",
  "reviewed": true,
  "estimated": false
}
```

For foods measured in ml when USDA is per 100 g, a reviewed or USDA-derived
`density_g_per_ml` is required. For foods measured as pieces, a reviewed or
USDA-derived `grams_per_piece` is required.

The calculation intentionally does not model nutrient retention/loss during
cooking, so the UI states that limitation.
