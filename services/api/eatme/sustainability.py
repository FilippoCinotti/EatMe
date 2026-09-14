"""Conservative, versioned estimates for recorded at-risk food use.

The factors are a small bundled snapshot, not a live scoring service.  Foods
without an exact supported proxy or a mass unit are deliberately excluded.
"""
from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP

from .storage import decode


METHOD_VERSION = "at-risk-use-v1"
FACTOR_VERSION = "poore-nemecek-owid-2019-v1"
FACTOR_SOURCE = {
    "title": "Poore and Nemecek (2018), processed by Our World in Data",
    "url": "https://ourworldindata.org/grapher/ghg-per-kg-poore",
    "doi": "10.1126/science.aaq0216",
    "unit": "kg_co2e_per_kg_product",
    "retrieved_at": "2026-09-14",
}

# Exact catalog-slug to source-product proxies. Values are global means from
# the cited dataset. The proxy name remains in the response for auditability.
CARBON_FACTORS = {
    "tomato": (Decimal("2.09"), "Tomatoes"),
    "zucchini": (Decimal("0.53"), "Other Vegetables"),
    "spinach": (Decimal("0.53"), "Other Vegetables"),
    "chickpea": (Decimal("1.79"), "Other Pulses"),
    "rice": (Decimal("4.45"), "Rice"),
    "pasta": (Decimal("1.57"), "Wheat & Rye"),
    "feta": (Decimal("23.88"), "Cheese"),
    "chicken": (Decimal("9.87"), "Poultry Meat"),
    "peanut": (Decimal("3.23"), "Groundnuts"),
}


def _day(value: str) -> date:
    return datetime.fromisoformat(value.replace("Z", "+00:00")).date()


def _money(value) -> Decimal | None:
    try:
        number = Decimal(str(value))
        return number if number.is_finite() and number >= 0 else None
    except (InvalidOperation, TypeError, ValueError):
        return None


def estimate_savings(rows: list[dict]) -> dict:
    """Estimate value represented by food used within two days of its date.

    This is intentionally a proxy: a recorded use near a package date cannot
    prove a counterfactual discard or a future avoided purchase. Money uses
    only user-recorded batch cost; carbon uses only supported gram-based foods.
    """
    carbon = Decimal(0)
    carbon_grams = Decimal(0)
    eligible_grams = Decimal(0)
    money: dict[str, Decimal] = {}
    eligible_events = carbon_events = priced_events = 0
    factor_proxies: set[str] = set()

    for row in rows:
        expiry = row.get("expiry_date")
        if not expiry or row.get("expiry_kind") == "unknown":
            continue
        used = _day(row["created_at"])
        days = (date.fromisoformat(expiry) - used).days
        if not 0 <= days <= 2:
            continue
        amount_milli = abs(int(row.get("delta_milli") or 0))
        if not amount_milli:
            continue
        eligible_events += 1
        food = decode(row["food_data"])
        metadata = decode(row["metadata"]) if row.get("metadata") else {}

        # One milli-unit is 0.001 g for gram-based catalog foods.
        if food.get("unit") == "g":
            grams = Decimal(amount_milli) / Decimal(1000)
            eligible_grams += grams
            factor = CARBON_FACTORS.get(food.get("slug"))
            if factor:
                kg = grams / Decimal(1000)
                carbon += kg * factor[0]
                carbon_grams += grams
                carbon_events += 1
                factor_proxies.add(factor[1])

        cost = _money(metadata.get("cost"))
        initial_milli = row.get("initial_milli")
        currency = metadata.get("currency")
        if cost is not None and currency in {"EUR", "USD", "GBP", "CHF"} and initial_milli:
            share = min(Decimal(amount_milli) / Decimal(abs(int(initial_milli))), Decimal(1))
            money[currency] = money.get(currency, Decimal(0)) + cost * share
            priced_events += 1

    quantized_carbon = carbon.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    amounts = [
        {
            "currency": currency,
            "value": str(value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)),
        }
        for currency, value in sorted(money.items())
    ]
    return {
        "money_saved": {
            "estimated": True,
            "amounts": amounts,
            "covered_events": priced_events,
        } if amounts else None,
        "carbon_saved": {
            "estimated": True,
            "value": str(quantized_carbon),
            "unit": "kg_co2e",
            "covered_quantity_g": str(carbon_grams.quantize(Decimal("0.1"))),
            "eligible_quantity_g": str(eligible_grams.quantize(Decimal("0.1"))),
            "covered_events": carbon_events,
            "factor_version": FACTOR_VERSION,
            "factor_proxies": sorted(factor_proxies),
        } if carbon_events else None,
        "savings_method": {
            "version": METHOD_VERSION,
            "label": "recorded_at_risk_food_used",
            "eligible_events": eligible_events,
            "date_window_days": 2,
            "money_basis": "recorded_batch_cost_allocated_by_initial_quantity",
            "carbon_basis": "recorded_mass_times_global_mean_product_factor",
            "factor_source": FACTOR_SOURCE,
            "limitations": [
                "use_near_a_recorded_date_is_a_proxy_not_proof_of_prevented_waste",
                "money_is_recorded_food_value_not_verified_cash_savings",
                "carbon_excludes_unmapped_foods_and_non_mass_units",
            ],
        },
    }
