# Reference feature parity

Source: the seven light-theme EatMe boards supplied by the owner on September 13, 2026. Implementation starts from main commit `9e556323b00e9e2d0f6da914f4b0b464db70b893`. This checklist describes working flows, not just visual similarity. The additions below are implemented; verification status and provider-dependent boundaries are listed separately.

| Reference area | Existing behavior | Added in this change |
| --- | --- | --- |
| Welcome and account | Email authentication, development accounts, production Apple/Google login and password recovery | Welcome flow, password visibility and confirmation, explicit terms/privacy acknowledgement |
| Onboarding and dietary profile | Household size, multiple diets, strictness, allergies, intolerance and consent | Primary goal, primary diet, editable habit goals and progress |
| ChefTable | Ranked suggestions, quick/use-soon/no-shopping modes, recipes and favorites | Plant-based mode, favorite shortcut and preservation of recommendation notices |
| Recipe and cooking | Ingredients, servings, nutrient totals, guided steps, five-minute timer, stock confirmation and leftovers | Recipe sharing, configurable timer and completion screen linking saved leftovers and sharing |
| Pantry | Storage filters, search, known-food entry, quantity/location/date/notes editing | All-storage view, sorting, grouped expiry page, add-method sheet and custom food with optional photo |
| HealthyFood | Category grid and compatibility assessment | Food favorites, functional information/nutrition/personal tabs, source links and add-to-pantry action |
| Scanning | Barcode lookup, photo/receipt jobs, per-item confirmation and atomic import | Camera/gallery choices, torch/retry, per-item storage/date controls and batch review controls |
| Shopping | Persistent checked items, edits, deletion, meal-plan generation and purchase transactions | Category headings with progress and shareable list |
| Meal planning | Week selection, four meal slots, portions, household diners and recipe selection | Existing four-slot weekly planner retained and linked from insights tips |
| Leftovers | Stored portions after cooking, dates, moving, consume/discard and validated transformation | Direct entry for externally prepared leftovers and clear available/reuse views |
| Shared fridge | Invitations, ownership transfer, membership roles and explicit dietary sharing | Recent inventory activity with household access enforcement |
| Insights and notifications | Recorded cooking/event counts, reminders and notification inbox | Overview/alerts/tips, expiring-food links and weekly self-reported habit progress |

## Data boundaries

The mockup values (85/100, 92/100, 91/100, 2.3 kg saved, 5.6 kg CO2 and AI confidence percentages) are illustrative. Progress must derive from recorded actions or explicitly labelled self-reports. Nutrient data must retain its basis and attribution. A validated nutritional or clinical scoring method is not present in the repository: score widgets must show an unavailable state rather than manufacture a score. Clinical profiles, including RAD, remain subject to the existing published-rule and consent checks.

Custom food remains household-scoped and is not treated as a curated ingredient. Scans require confirmation; entered package dates retain their date type and are never inferred as food-safety assurances. Sharing uses the device share sheet and does not automatically publish community content.

## Verification

- Local repository checks pass with 559 matching English/Italian localization keys.
- API suite: 67 tests, with three environment-dependent skips locally. Nine new domain tests cover custom-food access, photo revocation and deletion, household activity, favorite preservation, habit rollovers, version checks, idempotency and external leftovers without duplicate consumption.
- Flutter interaction tests cover habit check-in/undo, custom-food validation and stable scan-review fields after deleting an item. Android/iOS CI validation is in progress on PR #15.
- Existing API, PostgreSQL isolation and studio CI jobs passed for the feature branch. Exact final mobile evidence will be recorded after platform validation.

## Scope and provider dependencies

- Photo and receipt recognition uses the existing asynchronous configured-provider workflow. Users can choose camera or gallery, review each identification, quantity, location and date, remove detections, and import the confirmed batch atomically. This is not a live camera overlay with tracking boxes; no live detection accuracy is claimed.
- Barcode scanning uses the native scanner, flashlight and retry controls. Product lookup requires the configured catalog provider and network; manual entry remains available.
- External leftovers reference an exact recipe with confirmed ingredients and a declared preparation date. Create a private recipe first if the dish is not in the library. Recording these portions does not remove raw ingredients or inflate meals cooked in the app.
- Nutrition values and evidence display only source-backed available data. Numeric personal/clinical scores and estimated carbon or money savings remain unavailable because this repository has no validated model for them.
- Recipe/list sharing opens the operating system share sheet. Public community publishing is not added.
- Production email registration links the configured `TERMS_URL` and `PRIVACY_URL` and asks for acknowledgement. Public registration still requires the operator's completed legal pages and provider configuration; this UI is not a legal-compliance certification.

## New API contracts

All routes are under `/api/v1` and require authentication. Writes use the existing idempotency header.

| Route | Behavior |
| --- | --- |
| `POST /foods` | `create`: custom name/category/unit/quantity/location/date/notes and optional uploaded `food` media. `favorite`: personal food ID and enabled flag. |
| `GET /foods/{id}/photo` | Authorized household photo as base64 JPEG. No public media URL. |
| `GET /wellbeing` | Current local week, self-reported days, personal targets and optimistic version. |
| `POST /wellbeing` | `target`, `check_in`, or `remove`, with `expected_version`. Check-ins apply to today in the profile timezone. |
| `GET /households/activity` | Last 100 inventory events from the active household, without health settings or raw event metadata. |
| `POST /leftovers` | Additional `create` action for externally prepared portions, recipe ID, preparation date, location, optional use date and ingredient confirmation. |

The existing JSON-backed catalog, preferences and media tables support these fields; no database migration is needed. Habit fields and food favorites cannot be overwritten through generic preference edits.
