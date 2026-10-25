# Explicit household meal-plan sharing

Existing personal plans remain private. The plan author can explicitly share a plan with the current household or make it private again. Authorized members can read and edit shared plans; viewers can read but cannot mutate them. Only the author changes visibility. Missing participant lists are made explicit as the original creator when sharing so another editor is never silently substituted as the diner.

All shared edits retain the existing household transaction serialization, idempotency and optimistic plan version. Simultaneous stale writes return `stale_plan` and the existing error/Retry flow lets the member reload before reconciling. Recipe changes still require participant-constraint consent and centralized Diet-Fit validation. No health fields are added to shared payloads. Shared plans can use the existing confirmed shopping-generation flow.

Resource screens refresh on app resume when current and not mutating; pull-to-refresh remains available. This is not a realtime implementation. Foreground realtime updates, richer field-level reconciliation, guest participants and two-physical-device validation remain outstanding. Existing avatar/tap household participant selection is reused.

Two regression tests cover private/shared visibility, explicit participant provenance, concurrent versions, author-only visibility, read-only members and access revocation after leaving. No database migration: sharing extends existing versioned plan JSON and backend-only plan access. No production change, merge or deployment.
