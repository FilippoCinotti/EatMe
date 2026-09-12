# Implementation status

The application branch now contains connected Flutter screens and API workflows for shopping, plans, households, private recipes, leftovers, processing jobs, editorial governance, privacy, preferences and native integrations. The foundation-only scope has been superseded.

The implemented application compiles into an Android debug APK and an iOS simulator application. API, database isolation, studio and Flutter widget checks have passed. The real API Android emulator workflow needs its corrected network waits verified. GitHub Actions currently fails before running any steps, including on retry; read `verification.md` for the evidence, owner action and exact tested commit. Development fixtures are not production data and are not evidence of recognition accuracy or clinical validity.

External release prerequisites include a deployed HTTPS backend, Supabase/provider accounts, qualified content reviewers, legal/support resources, Apple/Google signing and store accounts, subscription configuration when used, and physical-device validation. These prerequisites do not excuse unfinished software workflows; missing implementation remains a release blocker.
