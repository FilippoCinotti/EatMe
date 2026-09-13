# Reference feature parity

Source: the seven light-theme EatMe boards supplied by the owner on September 13, 2026. Implementation starts from main commit `9e556323b00e9e2d0f6da914f4b0b464db70b893`. This checklist describes working flows, not just visual similarity. Statuses are updated with implementation and verification evidence.

| Reference area | Existing behavior | Work to complete |
| --- | --- | --- |
| Welcome and account | Email authentication, development accounts, production Apple/Google login and password recovery | Welcome flow, password visibility and confirmation, explicit terms/privacy acknowledgement |
| Onboarding and dietary profile | Household size, multiple diets, strictness, allergies, intolerance and consent | Primary goal, primary diet, editable habit goals and progress |
| ChefTable | Ranked suggestions, quick/use-soon/no-shopping modes, recipes and favorites | Plant-based mode, favorite shortcut and preservation of recommendation notices |
| Recipe and cooking | Ingredients, servings, nutrient totals, guided steps, five-minute timer, stock confirmation and leftovers | Recipe sharing, configurable timer and completion screen linking saved leftovers and sharing |
| Pantry | Storage filters, search, known-food entry, quantity/location/date/notes editing | All-storage view, sorting, grouped expiry page, add-method sheet and custom food with optional photo |
| HealthyFood | Category grid and compatibility assessment | Food favorites, functional information/nutrition/personal tabs, source links and add-to-pantry action |
| Scanning | Barcode lookup, photo/receipt jobs, per-item confirmation and atomic import | Camera/gallery choices, torch/retry, per-item storage/date controls and batch review controls |
| Shopping | Persistent checked items, edits, deletion, meal-plan generation and purchase transactions | Category headings with progress and shareable list |
| Meal planning | Week selection, four meal slots, portions, household diners and recipe selection | Verify board parity and access from the main workflows |
| Leftovers | Stored portions after cooking, dates, moving, consume/discard and validated transformation | Direct entry for externally prepared leftovers and clear available/reuse views |
| Shared fridge | Invitations, ownership transfer, membership roles and explicit dietary sharing | Recent inventory activity with household access enforcement |
| Insights and notifications | Recorded cooking/event counts, reminders and notification inbox | Overview/alerts/tips, expiring-food links and weekly self-reported habit progress |

## Data boundaries

The mockup values (85/100, 92/100, 91/100, 2.3 kg saved, 5.6 kg CO2 and AI confidence percentages) are illustrative. Progress must derive from recorded actions or explicitly labelled self-reports. Nutrient data must retain its basis and attribution. A validated nutritional or clinical scoring method is not present in the repository: score widgets must show an unavailable state rather than manufacture a score. Clinical profiles, including RAD, remain subject to the existing published-rule and consent checks.

Custom food remains household-scoped and is not treated as a curated ingredient. Scans require confirmation; entered package dates retain their date type and are never inferred as food-safety assurances. Sharing uses the device share sheet and does not automatically publish community content.

## Verification

Pending implementation. Domain tests will cover privacy boundaries, retries and duplicate prevention, date validation and progress calculations. Flutter tests will cover newly connected flows and mobile layouts before Android/iOS CI publication.
