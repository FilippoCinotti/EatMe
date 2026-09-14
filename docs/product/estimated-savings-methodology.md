# Estimated money and CO₂e methodology

## What the metric means

EatMe reports conservative **estimated savings** for recorded at-risk food that the user consumed or cooked. “At risk” means the use event occurred from zero to two calendar days before the batch's recorded date. The calculation deliberately does not include a batch with an unknown date type.

This is a proxy, not a verified counterfactual. Using food near its recorded date does not prove that it otherwise would have been discarded, that a purchase was avoided, or that cash remained in the user's account. The UI therefore labels money as “estimated food value used” and carbon as “estimated CO₂e represented.” When the required inputs are absent, it shows unavailable instead of zero or an invented value.

Method version: `at-risk-use-v1`.

## Money

Money is calculated only when the inventory batch has a non-negative user-recorded cost, a supported currency and a recorded initial quantity.

For each eligible use event:

`estimated value = recorded batch cost × min(quantity used ÷ initial batch quantity, 1)`

Supported recorded currencies are EUR, USD, GBP and CHF. Values in different currencies remain separate; EatMe performs no exchange-rate conversion. Results are rounded to two decimal places. Receipt or manual cost remains the source of truth—there is no catalog-average price and no inferred package price.

## CO₂e

CO₂e is calculated only for exact catalog foods measured in grams and explicitly mapped to a bundled factor proxy:

`estimated kg CO₂e = quantity used in kg × factor in kg CO₂e per kg product`

Factor version: `poore-nemecek-owid-2019-v1`. The values are global product means from Poore and Nemecek (2018), processed by Our World in Data: <https://ourworldindata.org/grapher/ghg-per-kg-poore>. Primary paper DOI: <https://doi.org/10.1126/science.aaq0216>. The bundled snapshot was retrieved on 2026-09-14.

| EatMe food | Source proxy | kg CO₂e/kg |
| --- | --- | ---: |
| Tomato | Tomatoes | 2.09 |
| Zucchini | Other Vegetables | 0.53 |
| Spinach | Other Vegetables | 0.53 |
| Chickpea | Other Pulses | 1.79 |
| Rice | Rice | 4.45 |
| Pasta | Wheat & Rye | 1.57 |
| Feta | Cheese | 23.88 |
| Chicken | Poultry Meat | 9.87 |
| Peanut | Groundnuts | 3.23 |

Foods without a confident exact proxy are excluded. Volume and piece units are excluded because EatMe does not guess density or per-item mass. The API returns both eligible and factor-covered mass so the UI can communicate coverage. CO₂e is rounded to 0.01 kg.

## Data contract

`GET /api/v1/insights` retains recorded activity and adds:

- `money_saved`: nullable, estimated, per-currency amounts and covered-event count;
- `carbon_saved`: nullable, estimated kg CO₂e, eligible/covered mass, factor version and used proxies;
- `savings_method`: method version, eligibility window, bases, source metadata and machine-readable limitations.

The Insights Impact tab displays both estimates, unavailable states, eligible-event count, factor coverage and a “How this is calculated” explanation. No health, nutrition or environmental-benefit score is derived from these values.

## Known limitations

- The two-day window is a transparent product heuristic, not proof of prevented waste.
- The recorded package date can be best-before or use-by; the methodology does not reinterpret either date as a disposal prediction.
- User-entered cost can be incomplete or inaccurate.
- A food's global-average carbon factor does not describe the user's exact farm, transport, retail or cooking conditions.
- The factor table is intentionally narrow. Unmapped and non-mass foods reduce coverage rather than borrowing a guess.
- Cooking energy, packaging, travel, disposal pathway and rebound effects are excluded.
