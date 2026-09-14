# Reference feature parity

Source: the original EatMe boards supplied on September 13, 2026 plus the two approved Social Recipe Import / Smart Diet-Fit storyboards supplied on September 14, 2026. The current pass preserves the validated PR #15 implementation and starts from branch baseline `e20599cf1cb7bd6fabea86bb4f8df418de473ae7`. This checklist describes working flows, not just visual similarity.

| Reference area | Existing behavior | Added in this change |
| --- | --- | --- |
| Welcome and account | Email authentication, development accounts, production Apple/Google login and password recovery | Welcome flow, password visibility and confirmation, explicit terms/privacy acknowledgement |
| Onboarding and dietary profile | Household size, multiple diets, strictness, allergies, intolerance and consent | Primary goal, primary diet, editable habit goals and progress |
| ChefTable | Ranked suggestions, quick/use-soon/no-shopping modes, recipes and favorites | Plant-based mode, favorite shortcut and preservation of recommendation notices |
| Recipe and cooking | Ingredients, servings, nutrient totals, guided steps, five-minute timer, stock confirmation and leftovers | Recipe sharing, configurable timer and completion screen linking saved leftovers and sharing |
| Pantry | Storage filters, search, known-food entry, quantity/location/date/notes editing | All-storage view, sorting, grouped expiry page, add-method sheet and custom food with optional photo |
| HealthyFood | Category grid and compatibility assessment | Editorial favorite-led discovery, visual categories, functional information/nutrition/personal tabs, source links and add-to-pantry action |
| Scanning | Barcode lookup, photo/receipt jobs, per-item confirmation and atomic import | Dedicated camera-first acquisition, framing guidance, gallery, explicit photo review, permission/offline/processing states and existing atomic review controls |
| Social recipe import | Generic recipe URL prompt and private recipe editor | Public YouTube/Instagram entry, staged extraction, mandatory recipe review, canonical mapping, complete safety/diet assessment, inventory match, curated user-selected substitutions, full re-check, provenance, save and Cook Now |
| Shopping | Persistent checked items, edits, deletion, meal-plan generation and purchase transactions | Category headings with progress and shareable list |
| Meal planning | Week selection, four meal slots, portions, household diners and recipe selection | Existing four-slot weekly planner retained and linked from insights tips |
| Leftovers | Stored portions after cooking, dates, moving, consume/discard and validated transformation | Direct entry for externally prepared leftovers and clear available/reuse views |
| Shared fridge | Invitations, ownership transfer, membership roles and explicit dietary sharing | Recent inventory activity with household access enforcement |
| Insights and notifications | Recorded cooking/event counts, reminders and notification inbox | Premium Overview/Impact/Alerts/Tips, deterministic estimated food value and CO₂e with coverage/method drill-down, expiring-food links and weekly self-reported habit progress |

## Data boundaries

The mockup values (85/100, 92/100, 91/100, 2.3 kg saved, 5.6 kg CO₂ and AI confidence percentages) are illustrative and are never copied. Progress derives from recorded actions or explicitly labelled self-reports. Nutrient data retains its basis and attribution. A validated nutritional or clinical scoring method is not present in the repository: score widgets show unavailable rather than manufacturing a score. Money and CO₂e now use the separate deterministic, conservative and versioned methodology documented in `estimated-savings-methodology.md`; absent inputs remain unavailable. Clinical profiles, including RAD, remain subject to the existing published-rule and consent checks.

Custom food remains household-scoped and is not treated as a curated ingredient. Scans require confirmation; entered package dates retain their date type and are never inferred as food-safety assurances. Sharing uses the device share sheet and does not automatically publish community content.

## Verification

- Local repository checks pass with 559 matching English/Italian localization keys.
- API suite: 67 tests, with three environment-dependent skips locally. Nine new domain tests cover custom-food access, photo revocation and deletion, household activity, favorite preservation, habit rollovers, version checks, idempotency and external leftovers without duplicate consumption.
- Flutter interaction tests cover habit check-in/undo, custom-food validation and stable scan-review fields after deleting an item. Android/iOS CI validation is in progress on PR #15.
- Existing API, PostgreSQL isolation and studio CI jobs passed for the feature branch. Exact final mobile evidence will be recorded after platform validation.

## Scope and provider dependencies

- Photo and receipt recognition uses the existing asynchronous configured-provider workflow behind a dedicated EatMe acquisition screen. Users can choose camera or gallery, review the captured photo, then review each identification, quantity, location and date, remove detections, and import the confirmed batch atomically. This is not a live camera overlay with tracking boxes; no live detection accuracy is claimed.
- Barcode scanning uses the native scanner, flashlight and retry controls. Product lookup requires the configured catalog provider and network; manual entry remains available.
- External leftovers reference an exact recipe with confirmed ingredients and a declared preparation date. Create a private recipe first if the dish is not in the library. Recording these portions does not remove raw ingredients or inflate meals cooked in the app.
- Nutrition values and evidence display only source-backed available data. Numeric personal/clinical scores remain unavailable. Estimated money requires recorded batch cost and initial quantity; estimated CO₂e requires an eligible gram-based food with an exact documented factor mapping.
- Social import reads only public structured metadata with the SSRF-hardened existing HTTP transport. It does not log into providers, bypass private content or guarantee extraction. Partial drafts require correction and unknown canonical mappings prevent a compatibility claim or permanent save.
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
| `POST /recipes/import-url` | Validate a public YouTube/Instagram URL and return only extracted source fields, attribution, mapping states and missing fields; creates no recipe. |
| `POST /recipes/import-review` | Run the existing complete compatibility engine plus quantity-aware inventory coverage and compatible curated substitution candidates against the reviewed draft. |
| `GET /insights` | Recorded activity plus nullable versioned estimated food value and CO₂e, factor coverage, source metadata and limitations. |

The existing JSON-backed catalog, preferences and media tables support these fields; no database migration is needed. Habit fields and food favorites cannot be overwritten through generic preference edits.
