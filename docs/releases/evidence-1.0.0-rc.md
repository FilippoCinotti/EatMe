# EatMe+ 1.0.0 release-candidate evidence

Evidence date: 2026-09-21 UTC. This record distinguishes repository validation from external account and physical-device gates.

| Evidence | Result |
| --- | --- |
| Working branch | `feat/dinner-guests` (PR #29, draft) |
| Reconciled base | `main` `421da2ea6848c8afc088a7114b66987c495fd7c3`; current `main` remained unchanged during this pass |
| Reviewed source before this evidence update | `0d4b46c5e90c37bbd3052d80e7b3f303806d5c17` |
| Version / bundle | `1.0.0` / `com.filippocinotti.eatme` |
| Public names | EatMe+ application; EatMe Premium subscription tier |
| Flutter / Dart | Flutter `3.47.2`; Dart `3.13.2` |
| API | 102 passed and one optional PostgreSQL test skipped locally; CI unit tests, Ruff, repository validation, dependency audit and Docker build passed |
| Database | Migrations 0001–0006 and PostgreSQL/RLS/tenant-isolation tests passed in CI |
| Web applications | Guest, Admin and public site typecheck, production build, dependency audit and Docker build passed in CI |
| Flutter | Analyzer, 125 tests and localization contract passed on Linux and macOS in CI |
| Android / iOS | Android debug APK and emulator integration passed; iOS Simulator build and archive artifact passed |
| Formatting follow-up | CI #148 found only one Dart 3.13 formatting drift after the successful builds; corrected in `1176ac8bb30027ca8113e45e60c4739944b52b9a` |
| Screenshots | 148 real renders: 116 mobile, 27 Guest Web and 5 localization smoke renders; manifest/file coverage passes |
| Screenshot source | `1176ac8bb30027ca8113e45e60c4739944b52b9a`; the subsequent HSTS change does not alter rendered UI |
| Supabase | Project `ngqetldudwzemdhjprmv` healthy; migrations 0001–0006 reconciled; RLS effective; no Security Advisor WARN/ERROR |
| Private media | Private `eatme-private-media` Supabase Storage bucket; service-role-only access; application encryption retained |
| Crashlytics | SDK, release-only collection, framework/platform capture, iOS dSYM and CI upload integration committed; Firebase console app registration and controlled event receipt remain unverified |
| Render | GitHub App reconnected with access limited to `FilippoCinotti/EatMe`; Blueprint reads the RC branch; no services created because billing information is not yet on file |
| Cloudflare | Domain owned; DNS/TLS not created because Render origins do not yet exist |
| Signed IPA / TestFlight | Not built or uploaded |

## Required external evidence still outstanding

- Add billing information to Render, review the resulting service cost, securely enter production secrets, create the Blueprint services and verify each health check.
- Add Render custom domains before Cloudflare DNS; verify certificates and HTTPS, then enable Full (strict) and only later opt in to HSTS with `ENABLE_HSTS=true`.
- Complete Firebase iOS/Android registration in project `eatme-project`, supply protected configuration, and receive one controlled symbolicated release event.
- Configure and externally receive registration, verification and password-reset email through production SMTP with SPF, DKIM and DMARC.
- Complete Apple/Google provider lifecycle, App Store Connect signing, RevenueCat sandbox purchase/restore/expiration, and live assisted-processing acceptance or disable assisted processing for beta.
- Run the documented physical-iPhone acceptance matrix and record device, iOS version and build number.
- Run the protected TestFlight workflow against the exact reviewed and merged `main` SHA, validate the signed IPA, upload it, wait for processing and install it from TestFlight.

The application is not described as deployed or uploaded until those external checks produce real evidence.
