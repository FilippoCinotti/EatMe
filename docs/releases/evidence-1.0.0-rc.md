# EatMe+ 1.0.0 release-candidate evidence

Evidence date: 2026-09-19 UTC. This record is intentionally explicit about uncompleted external release gates.

| Evidence | Result |
| --- | --- |
| Working branch | `feat/dinner-guests` (PR #29, draft) |
| Reconciled base | merge commit `e5f245c7396791d2fe66ad7e27af3d8251fff5d9` includes `main` `421da2ea6848c8afc088a7114b66987c495fd7c3` |
| Version | `1.0.0` |
| Build | Not assigned; must be checked against App Store Connect |
| Bundle ID | `com.filippocinotti.eatme` |
| Flutter / Dart | Flutter `3.47.2`; Dart `3.13.2` |
| Release Xcode | Workflow pins stable Xcode `26.3`; no macOS/Xcode execution in this workspace |
| API tests | 99 passed, 3 skipped (optional FastAPI/PostgreSQL environments), 0 failed |
| Guest Web | Typecheck and production build passed |
| Supabase | Project `ngqetldudwzemdhjprmv` healthy; migrations `0001`–`0006` applied |
| RLS advisor | No warning/error; two informational RLS-without-policy findings on inaccessible development tables |
| Screenshots | 110 real mobile renders inventoried; release requirement is 146; 36 pending |
| Localization | Guilty Pleasure release contract passes in en/it/es/fr/de/zh-Hans; legacy strings use English fallback outside en/it |
| Signed IPA | Not built: macOS signing assets are unavailable in this workspace |
| IPA checksum | Not available |
| TestFlight | Not uploaded |

## Blocking evidence still required

- Four new Flutter Guilty Pleasure renders and 32 Guest/localization renders; generators are committed, but this workspace cannot run Flutter and Playwright's Chromium download returned timeout/502 failures.
- Full macOS release workflow, signed IPA validation and physical-device acceptance.
- Reachable production HTTPS API and Guest Web, canonical domain/DNS/TLS, transactional email, crash monitoring, uptime alerts and live AI/provider smoke tests.
- App Store Connect record, next unused build number, signing/API credentials, agreements and internal group status.
- RevenueCat offering, entitlement and StoreKit product validation with actual localized prices.

No upload should be attempted while these gates are red.
