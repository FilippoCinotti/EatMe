# Release process

## Application verification

Require a clean reproducible checkout, reviewed native projects and lockfiles, passing API/HTTP tests, PostgreSQL isolation tests, Flutter analysis/widget/integration checks, native debug builds and studio checks. Enable GitHub Code scanning and resolve actionable findings. Test camera denial, photo-library recovery, offline startup, outbox conflicts, multi-user consent changes and account deletion on real devices.

## Deployment

Follow the [deployment runbook](deployment-runbook.md) for container setup, staging validation, monitoring and recovery. Run `python scripts/check_release_config.py apps/mobile/config/production.json` before producing store binaries.

Deploy the API behind HTTPS with Supabase authentication and PostgreSQL. Apply immutable migrations with the migration credential, then run the API using only its restricted database role. Deploy the worker with the same private media volume and encryption key. Configure backup/retention, health monitoring, gateway rate limiting and alerting. Deploy the studio with its server-only API URL and HTTP-only sessions.

Configure and exercise Google/Apple login, email verification, password recovery, identity deletion, Apple token revocation and provider outages. Publish approved food/recipe/evidence content through the review workflow. Do not enable an unreviewed medical profile. Set the legal operator/contact and publish privacy, terms, support and deletion-request pages.

## Android

The application identifier is `com.filippocinotti.eatme`. New submissions target Android API 36 under the requirements effective August 31, 2026. Recheck the [official target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en) at submission time.

Set `ANDROID_KEYSTORE_PATH`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD` in a secure build environment. Keep the keystore outside the repository. Copy the public configuration template to `apps/mobile/config/production.json` and replace its deployment values.

```bash
cd apps/mobile
flutter build appbundle --release --dart-define-from-file=config/production.json
```

Upload the signed bundle to an internal testing track first. Complete Data safety, content rating, account deletion, target audience, applicable health declarations, screenshots and store metadata. Never sign a release with the debug keystore.

## iOS

Open `apps/mobile/ios/Runner.xcworkspace` on macOS, select the correct Apple development team and signing profiles, and verify bundle capabilities and the aggregated privacy manifest. Use the simulator for early checks and physical devices for camera, sign-in and purchase lifecycle checks.

```bash
cd apps/mobile
flutter build ipa --release --dart-define-from-file=config/production.json
```

Distribute through TestFlight before submission. Supply reviewer access, an operational backend, support/privacy URLs, age rating, privacy disclosures and accurate screenshots. Review the [App Store guidelines](https://developer.apple.com/app-store/review/guidelines/) against the actual deployment. Signing and a successful build do not guarantee store acceptance.

## Release decision

Record the tested commit, build number, migration set, provider configuration, review evidence and rollback procedure. Increase the build number for each uploaded build. Roll out gradually, monitor failures and maintain a server-side kill switch for optional integrations. No public release should proceed while an implementation, validation or owner-configuration gate remains open.
