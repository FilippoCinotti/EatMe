# Missing subscription plans in TestFlight

The reported symptom is a subscription page that opens without purchasable plans.

## Evidence collected

- Production API health responds successfully and reports commit `f8120ac03f5b`.
- The server subscription table contains a completed verification at
  `2026-10-10T11:18:57.442239Z`. This supports a working server integration at
  that time; it is not a new end-to-end purchase validation.
- Inspected the actual signed build 22 artifact from Actions run `38045681367`.
  Its bundle identifier is `com.filippocinotti.eatme`, and its compiled public
  RevenueCat iOS SDK key matches the repository production configuration.
- A read-only RevenueCat offerings request using that public SDK key and
  `X-Platform: ios` returns HTTP 200, current offering `default`, and both:
  - `$rc_monthly`: `com.filippocinotti.eatme.premium.monthly`
  - `$rc_annual`: `com.filippocinotti.eatme.premium.annual`
- This request validates the default RevenueCat catalog, not a particular
  customer's targeting rules or the products returned by native StoreKit.
- Render logs did not identify a subscription exception. The sampled logs
  contain deployment/runtime messages, so their absence does not prove the
  device purchase flow works.

No purchases, customer overrides, premium grants, provider settings, releases
or deployments were performed during this investigation.

## App defect and correction

The page awaited `getCustomerInfo()` before calling `getOfferings()`. A failed
or slow customer-info request therefore hid purchasable plans even when the
store catalog was available. Fetch product and management-link information
independently, display products as soon as they arrive, and retain management
links even when offerings fail. Restore remains available after SDK connection.

Use the SDK's actual configuration/account state instead of a local static
boolean and avoid logging in again when the SDK already has the same account.
Reject stale callbacks after another load, account change or page disposal.
Distinguish missing purchase setup from unavailable native products and
temporary store errors. Show a loading indicator while native products are
being fetched instead of prematurely claiming no plans are available. Prices and purchasable packages still come exclusively
from the native SDK; backend entitlement verification is still required.

## Remaining device/store verification

RevenueCat's configured identifiers must also be retrievable from App Store
Connect by StoreKit on the TestFlight device. The correct public SDK key and a
valid RevenueCat catalog alone do not establish that. App Store Connect and
native StoreKit logs are unavailable through the connected tools here.

For both identifiers above, inspect the actual App Store Connect product state,
pricing, localization, availability and subscription group. Inspect the status
of the Paid Applications Agreement, tax and banking setup. Record the native
RevenueCat/StoreKit error code when opening the subscription page, then test
monthly/annual display, cancellation, purchase, restore and server-verified
premium activation in sandbox/TestFlight.

References:

- https://www.revenuecat.com/docs/offerings/troubleshooting-offerings
- https://www.revenuecat.com/docs/getting-started/entitlements/ios-products
- https://www.revenuecat.com/docs/api-v1/offerings

## Local validation

- Five catalog-loading regression cases pass in a standalone Dart harness:
  customer-info failure, slow metadata, offerings failure with management
  recovery, empty native results and stale callbacks.
- Dart analyzer passes for the changed files with repository lint rules and
  Flutter 3.47.2 source/package definitions.
- Localization contract passes with 1,168 keys across six locales.
- Flutter widget/device execution and real StoreKit purchases remain untested.
- Ordinary PR CI remains intentionally held with `[skip ci]` and a draft PR.
