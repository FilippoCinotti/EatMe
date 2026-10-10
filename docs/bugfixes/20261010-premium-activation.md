# Premium activation after a successful store purchase

## Root cause reproduced

TestFlight sends `POST /api/v1/entitlements/refresh` without a JSON body after Apple/RevenueCat purchase or restore succeeds. The endpoint shared `domain_command(body: dict, ...)` with other domain commands. FastAPI rejected the missing body with HTTP 422 before reaching RevenueCat verification. Mobile mapped this to the generic invalid-request/save failure and never invalidated its entitlement provider.

## Changes

- Give entitlement refresh a dedicated authenticated, bodyless API route. Existing installed clients can refresh once this API change is deployed. Device assertions never supply grants; the server verifies the authenticated account against RevenueCat as before.
- Mobile explicitly sends an empty JSON object and invalidates its shared entitlement provider after successful verification for the same account.
- Apply the returned server snapshot directly on the subscription screen after purchase or restore, keeping the visible store catalog instead of resetting the page and fetching the snapshot again.

## Verification

- The new regression fails against the previous API with HTTP 422 (missing body).
- All 8 FastAPI tests pass with the fix, including bodyless and empty-object requests, persisted Premium capabilities, authenticated RevenueCat account selection, no unauthenticated refresh, and no device-asserted grants.
- RevenueCat responses are mocked in these tests. Live TestFlight purchase/restore, current RevenueCat configuration, and device UI remain to verify after deployment.
- Flutter/Dart tooling is unavailable in this workspace; mobile compilation/analyzer have not been run here.
- Preserve the existing PR #83 hold: commit uses `[skip ci]`; no merge, API deployment or TestFlight release dispatched.
