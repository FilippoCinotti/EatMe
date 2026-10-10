# Build 23 subscription follow-up and biometric spacing

## Observed on 2026-10-10

The TestFlight screenshot still reports unavailable store products. The app maps
both an empty native package list and RevenueCat configuration/product-unavailable
errors to this message, so the screenshot alone does not distinguish them.

Read-only inspection of the signed-in RevenueCat project confirmed:

- App bundle: `com.filippocinotti.eatme`.
- Monthly and annual product identifiers match the repository configuration.
- The monthly product is associated with `eatme_premium` and offering `default`.
- Both App Store products show `Could not check`. The explanation identifies a
  connection issue with App Store Connect API credentials.
- The app's separate in-app purchase key displays `Valid credentials`.
- The App Store Connect API key section has no uploaded key.

The missing App Store Connect API key explains the dashboard's inability to check
product status. It is not established as the cause of native StoreKit returning no
plans. RevenueCat documents this key as supporting product/price imports:
https://www.revenuecat.com/docs/store-configuration/app-store/service-credentials-index

App Store Connect redirected to sign-in. The secure authentication attempt was
rejected by Apple with an account-information error. Product states, pricing,
localizations, territories, subscription groups and agreements remain unverified.
No credential material, provider settings, purchases or premium grants were
changed. Do not mark the subscription incident resolved until StoreKit retrieves
both plans on TestFlight and a sandbox purchase/restore is server-verified.

## Biometric preference layout

Use the shared `SettingsGroup` for the visible biometric preference. It provides
the existing theme-aware panel, 16 px horizontal/8 px vertical inset and 24 px
spacing before the next section heading. Preserve 13 px title and 12 px body/error
fonts. Unsupported devices still return an empty widget before creating a panel.

## Validation and release hold

Dart formatting checked. Targeted analyzer result recorded in the PR. Full Flutter
rendering/device checks remain pending; no Flutter engine or Xcode is available
locally. Keep this draft's commit marked `[skip ci]` while collecting the rest of
the user's requested changes. No new CI dispatch or release is authorized yet.
