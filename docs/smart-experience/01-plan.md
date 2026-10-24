# Smart Plan 2.0

The meal lock is immediate and persisted in `meal_plans.data.meals[].locked`. Unlock before manual edits. Preview generation includes the current plan ID and version and retains locked meals verbatim, including their participants and portions. The backend also rejects attempts by older clients to overwrite locks.

The meal menu suggests one alternative with accept, another, or cancel. The backend reuses `rank` and `_diners`, excludes the current recipe and rejected suggestions, prioritizes recipes absent from the week, and validates current participant restrictions again on acceptance. Previewing never modifies the plan.

Move, swap and reuse select a day and meal type. Move and copy require an empty target; swap requires an occupied target. Both ends of a swap must be unlocked. Delete skips the meal. Changes are restricted to the current seven-day plan. The shopping list changes only through its existing explicit generation action.

A clock action beside the selected day edits its estimated preparation time budget. Leave empty for no limit. Budgets are stored as ISO date keys in `meal_plans.data.daily_limits`; they constrain generated alternatives and new/changed meals. Locked meals are retained even when they exceed a newly selected budget. Times are estimates, not guarantees.

## Persistence and compatibility

No SQL migration is necessary. Existing plan JSON and existing schema remain compatible; missing lock means unlocked, missing daily budget means unlimited. Unknown top-level plan metadata is preserved. Commands share existing household transaction serialization, idempotency keys, access control, and optimistic plan versions. Stale requests return `stale_plan`; reload with the existing Retry action before reconciling. Personal plan ownership remains unchanged in this PR; shared plan access is a separate Household requirement.

## Verification

- Seven new backend regression tests: lock persistence and generation, single alternative isolation, rescheduling, retry and stale version, time budgets, locked target, Premium gating.
- Existing domain tests pass.
- Full local API suite: 211 tests, 12 skips (environment-dependent checks).
- Flutter SDK is not installed in the editing environment. Flutter analysis, tests, screenshots, Android and iOS builds require the existing GitHub CI. These gates are pending, not passed.
- Device, Split View, Stage Manager, screen reader and screenshot review remain pending.

No production migration, secrets change, merge or deployment is part of this PR.
