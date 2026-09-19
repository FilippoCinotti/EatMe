# TestFlight release runbook

This runbook is for the frozen EatMe 1.0 release candidate. Ordinary CI remains separate from `.github/workflows/testflight.yml`; the release workflow runs only by manual dispatch, checks out an exact commit that is already contained in `main`, and uses the protected `testflight` GitHub environment.

## Fixed release identity

| Item | Value |
| --- | --- |
| Marketing version | `1.0.0` |
| Bundle identifier | `com.filippocinotti.eatme` |
| Flutter | `3.47.2` |
| Dart | Flutter-bundled version (recorded by workflow) |
| macOS runner | `macos-15` |
| Xcode | `26.3` stable |
| Initial group | `EatMe Internal` |

Apple requires App Store Connect uploads to be built with Xcode 26 or later from 28 April 2026. Xcode 26.3 is a stable release that Apple lists as supported on macOS Sequoia 15.6 and later. Revalidate both facts before each upload: [Apple upcoming requirements](https://developer.apple.com/news/upcoming-requirements/) and [Xcode system requirements](https://developer.apple.com/xcode/system-requirements).

Never guess a build number. App Store Connect requires a monotonically increasing value, so the workflow makes `build_number` an explicit required input.

## Apple and GitHub prerequisites

1. Confirm the existing App Store Connect record for the production bundle ID. Do not create a duplicate.
2. Enable Sign in with Apple for the App ID and confirm the capability, Supabase provider, redirect path, returning login, cancellation, relay email and account-deletion/token-revocation flow.
3. Create an App Store distribution certificate and an App Store provisioning profile for the same App ID. Export the certificate with its private key as password-protected PKCS#12.
4. Create a least-privilege App Store Connect API key that can upload builds. Never use an Apple ID password or a stored 2FA code.
5. Create a protected GitHub environment named `testflight`, require reviewer approval, and restrict it to `main`/reviewed release references.
6. Confirm current agreements, tax and banking configuration where paid subscriptions are to be tested.

### Protected secrets

| GitHub secret | Contents |
| --- | --- |
| `APP_STORE_CONNECT_ISSUER_ID` | API issuer ID |
| `APP_STORE_CONNECT_KEY_ID` | API key ID |
| `APP_STORE_CONNECT_API_KEY_P8` | Complete private `.p8` key |
| `IOS_DISTRIBUTION_CERTIFICATE_BASE64` | Base64 PKCS#12 distribution identity |
| `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD` | PKCS#12 password |
| `IOS_PROVISIONING_PROFILE_BASE64` | Base64 App Store provisioning profile |
| `IOS_PROVISIONING_PROFILE_NAME` | Exact profile name used for manual export |
| `IOS_KEYCHAIN_PASSWORD` | Ephemeral CI keychain password |
| `APPLE_TEAM_ID` | Apple Developer team ID |
| `SUPABASE_PUBLISHABLE_KEY` | Public mobile key, stored as a secret to reduce log exposure |
| `REVENUECAT_IOS_PUBLISHABLE_KEY` | Public iOS SDK key (`appl_…`) |

### Protected variables

| GitHub variable | Requirement |
| --- | --- |
| `PRODUCTION_API_URL` | Reachable HTTPS URL ending `/api/v1` |
| `SUPABASE_URL` | `https://ngqetldudwzemdhjprmv.supabase.co` |
| `PRIVACY_URL` | Final reachable HTTPS privacy page |
| `TERMS_URL` | Final reachable HTTPS terms page |

Server secrets such as the Supabase service role, RevenueCat secret, Apple private server key, AI API key, database credentials and media encryption key never belong in the Flutter build or this workflow's public Dart defines.

## Build and upload

Before dispatch, ordinary CI and the screenshot coverage gate must be green on the exact reviewed SHA. In GitHub Actions, select **TestFlight release candidate**, enter that SHA and the next unused build number, leave upload enabled, and approve the protected environment.

The workflow validates the source ancestry; tests API, Guest Web and Flutter; validates localization and screenshot coverage; checks a live API health endpoint; imports signing material into a temporary keychain; exports a real App Store IPA; checks bundle ID, version, build, privacy manifest, provisioning and signature; retains the IPA and checksum; validates and uploads with App Store Connect API authentication; and destroys temporary signing material.

The upload command succeeding means Apple accepted the binary upload. It does not mean processing has finished or the build is visible to testers. Confirm processing status in App Store Connect before assigning `EatMe Internal`.

## Internal acceptance

Use internal testing first. Validate cold launch, native Light/Dark splash, signup/login/Sign in with Apple, onboarding, ChefTable, Guilty Pleasure, Fridge acquisition paths, Social Import, Diet-Fit and substitutions, Plan/Shopping, Dinner/Guest RSVP in a separate browser, Adaptive Serving, cooking/stock/leftovers, EatMe+ purchase and restore, offline/reconnect, logout/login and account deletion on a physical iPhone.

Test monthly and annual products with StoreKit/TestFlight pricing supplied by RevenueCat; never hard-code the illustrative prices as store truth. Validate purchase, restore, expiry/cancellation, reconnect and Free fallback. External testing waits until the internal pass is accepted.

## Roll forward, not backward

An uploaded build number is immutable. For a release defect, fix only code, safety, privacy, performance, localization or release defects; increment the build number; run the same gates; upload a replacement. Do not reuse or overwrite an uploaded build and do not add product scope during the freeze.

## Beta notes

English and Italian beta notes are stored in `docs/releases/testflight-beta-notes.md`. App Store localized descriptions may be added only after their translations are reviewed; English fallback is preferable to an unsafe or misleading translation.
