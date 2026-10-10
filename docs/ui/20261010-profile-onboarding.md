# Compact profile onboarding

## Existing flow and reused design

The existing OnboardingPage contains six steps: personal details/goals, dietary styles, allergies (including eight specific tree nuts), intolerances/sensitivities, medical nutrition, and meal timing/meal slots/timezone. The final step is not an additional medical or personal-details form.

Reuse EatMeAppBar, PageBody, InformationPanel, EatMeToggleRow, theme input/button styles and EatMeDisplay/EatMeSans. The scoped OnboardingTag follows the Profile/Diet & Health action-pill seed palette (teal, indigo, amber, purple, deepOrange), localized-label seed assignment and theme brightness. Neutral surfaces stay neutral; selected tags have a tinted background, border and checkmark. Deselecting restores the neutral appearance.

Typography is scoped to this flow: main titles 22, section titles 14, descriptions/fields 13, tags 12, Continue 14, step indicator 11 logical pixels. Text scaling remains enabled. Wrapping labels and minimum 44-pixel interaction targets avoid truncating compact controls. Cards use the existing radius/padding; PageBody retains 20-pixel side margins. The footer scrolls with the page and safe-area padding, and changing steps dismisses the keyboard and resets the scroll without discarding form values.

The original option IDs, single/multiple selection behavior, age validation, complete consent wording and defaults, skip eligibility, submission payload and API integration are retained. No new visible strings require translation. The existing 23:23 dedication remains available. No authentication, subscription or backend changes are included.

## Verification (2026-10-10)

- Dart formatting with language version 3.8: passes.
- Dart analyzer for the onboarding directory and new visual tests: no issues.
- Flutter widget tests: all 20 pass.
- Six-step traversal in both themes at 390x844 and at 320x568 with 200% text scaling.
- All six locales (it, en, es, fr, de, zh) at 320 pixels / 200% text in both themes.
- Tag selection/deselection, unselected initial consents, consent acceptance and submitted profile payload.
- Keyboard inset of 260 pixels, forward/back navigation and retained name/diet selection.
- Missing adult confirmation and missing health consent prevent saving in both themes.
- Twelve full-content screenshots inspected, showing selected and neutral tags in both themes.

Run from apps/mobile:

```sh
flutter test test/onboarding_visual_test.dart
```

The tests generate `build/screenshots/onboarding-{light,dark}-{1..6}.png` using the Flutter renderer with bundled fonts and Material icons. These are full-scroll-content captures, not fixed-height device screenshots. Profile API calls are mocked; persistence is verified at the submission payload boundary. Physical iOS/Android devices and production backend persistence were not exercised.

This change is stacked on draft PR #83 to retain its existing fixes while keeping this PR's diff dedicated to onboarding. No merge, deployment or manual CI dispatch is performed.
