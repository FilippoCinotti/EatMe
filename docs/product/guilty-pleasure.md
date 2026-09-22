# Guilty Pleasure product contract

Guilty Pleasure is a temporary recommendation and meal-planning override. It is not a primary destination, dietary profile, health protocol or separate compatibility engine.

The default scope is **This meal**; **Today** is an explicit alternative. Mobile state expires automatically, meal scope clears after cooking confirmation, and scheduled Plan overrides apply only to their recorded date/slot. The permanent profile is never changed.

## Safety invariant

Only soft ranking pressure may be relaxed: ordinary macro/whole-food/plant-forward goals, cuisine/variety, non-excluded dislikes, speed, convenience and similar preferences. The existing Diet-Fit evaluator always runs first.

Allergies, hard may-contain/intolerance policy, Celiac restrictions, Always Exclude, medical/therapeutic rules marked hard, ethical/religious hard rules, unknown/canonical ingredient uncertainty and every household/guest hard restriction remain active. A conflict stays a conflict; Guilty Pleasure cannot relabel it as compatible.

Recommendations disclose honest context such as readiness, inventory availability or being outside a normal soft preference. Meal Memory may record the meal but never labels it cheating, failure or something to compensate for.

## Storage and API shape

Immediate mobile scope is stored in account-scoped secure storage with an expiry and fails closed when invalid/expired. Planned scope is validated inside the existing versioned meal-plan JSON as `preference_overrides`; no second evaluator or database table is introduced.

The API exposes `preference_context.soft_preferences_relaxed` and `hard_restrictions_active` for transparent presentation. Hard compatibility is computed before ranking in every mode.

## Release tests

The suite covers soft ranking change without profile mutation, meal/day isolation and expiry, allergies, Always Exclude, Celiac, unknown ingredients, guest allergies, invalid plan targets, offline restoration and all six release locales. Deterministic Light/Dark screenshots cover both active mode and its setup sheet.
