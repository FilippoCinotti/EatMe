# Firebase Crashlytics validation

EatMe+ uses the existing Firebase project `eatme-project`. Android and iOS Firebase apps must use `com.filippocinotti.eatme`. The Android `google-services.json` and iOS `GoogleService-Info.plist` are provider configuration files, not server credentials, but the release process injects them from protected storage and keeps them out of Git.

`FIREBASE_CRASHLYTICS_ENABLED=true` enables collection in Release builds only. Flutter framework failures and uncaught asynchronous/platform failures are recorded as fatal. The controlled validation event is non-fatal. Application code deliberately attaches no user identifier or custom recipe, food, dietary, health, guest, image or authentication fields.

The protected TestFlight workflow validates the Firebase project ID and bundle ID before building. Its Crashlytics symbol step fails the release if `upload-symbols` or archive dSYMs are missing, uploads every archive dSYM and stores a redacted evidence file containing only project/app identifiers and symbol count. Android applies the Google Services and Crashlytics Gradle plugins only when the matching provider configuration file is present; standard Release mapping upload remains enabled. Flutter code is not obfuscated in the current release command, so no separate `--split-debug-info` upload is required.

## Controlled internal verification

Never enable either validation flag in a public TestFlight build.

1. Build a separately numbered internal Release build with the production Firebase config and `FIREBASE_CRASHLYTICS_ENABLED=true`.
2. Add `CRASHLYTICS_VALIDATION_EVENT=true` to send one non-fatal event at startup. Confirm it appears under project `eatme-project` and that the stack is symbolicated.
3. For the final fatal-path check, use a second internal-only build with `CRASHLYTICS_VALIDATION_CRASH=true`. Launch it once, relaunch so the SDK can deliver the report, and confirm the event is symbolicated.
4. Remove both validation flags, increment the build number and run the protected TestFlight workflow for the candidate.

Record the device model, OS version, build number, Firebase app ID, event time and dashboard receipt. Do not capture or commit dashboard data containing device identifiers.
