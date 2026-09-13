# Premium redesign: Phase 0 reconciliation

Inspected the live GitHub repository before presentation changes on September 13, 2026.

- Default branch: `main`, HEAD `9e556323b00e9e2d0f6da914f4b0b464db70b893` (merged visual refresh PR #14).
- Relevant unfinished branch: `feat/reference-features`, remote HEAD `90941c2ac8fbcdcdbca417c11eee079a1a79ec00`, draft PR #15.
- Older app/foundation/visual branches are ancestors or already integrated work. They are not replacement baselines.
- PR #15 contains valid custom foods/photos, food favorites, weekly habit tracking, expiry browsing, scan review, external leftovers, recipe sharing, cooking completion, household activity and English documentation.
- CI run `34762114941`: API, PostgreSQL isolation and studio pass. Mobile analysis passes; one widget test fails because its scrolling finder matches multiple scrollable widgets. The local correction targets the outer scrollable explicitly. CI formatter output for the custom-food form is preserved.
- Reviewed actual Flutter source and test-rendered screenshots. The app still relies on generic headings, repeated cards/rows, and a feature-oriented ChefTable layout. The next phase replaces presentation primitives and hierarchy while preserving routes, actions and safety logic.

## Continuation decision

Continue `feat/reference-features` and PR #15. Commit the final functional test/format corrections before presentation changes. Keep backend contracts and validated functional work intact. Do not push directly to main or merge during the redesign.

## Approved references

Three images are available in this request: standalone ChefTable, Fridge comparison and HealthyFood comparison. Only the redesigned comparison screens are targets. Profile, submenus and authentication follow the owner's detailed written specification; their two additional boards were not attached in this message. No old comparison screen is used as a design target.

The visual references guide layout, imagery and hierarchy. Displayed account, dietary, nutrition, compatibility, expiry, ranking and subscription information must come from existing application state or clearly isolated test fixtures.

## Functional scope verification

Commit `87c23995af16c6ae3789b7e350b5ee8878a49251` completed the remaining test correction. All EatMe CI jobs passed in run `34776802964`: API, PostgreSQL/RLS, studio, Flutter analysis/tests/formatting, Android debug build and real emulator integration, and iOS simulator debug build. This is the verified functional baseline before the premium presentation commits. The separate CodeQL upload requires code scanning to be enabled for this repository.
