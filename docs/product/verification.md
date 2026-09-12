# Verification report

## Application validation

The foundation-only results are superseded by application checks. The tested implementation is `46ce8d7009e9e478518b179457be95261e1c41ca`, including the corrected integration-test synchronization and committed TypeScript 7 lockfile.

[Application CI](https://github.com/FilippoCinotti/EatMe/actions/runs/34704572429) completed successfully. This report-only update does not change the tested application source or workflow configuration.

Debug artifacts: [Android APK](https://github.com/FilippoCinotti/EatMe/actions/runs/34704572429/artifacts/10301554361) and [iOS simulator application](https://github.com/FilippoCinotti/EatMe/actions/runs/34704572429/artifacts/10305546772). Artifacts expire after 14 days; a new build can recreate them from the tested commit. Follow the [local setup guide](../development/local-setup.md) for installation and backend connectivity.

The completed run verifies the following:

| Check | Result at this checkpoint |
| --- | --- |
| Python API/domain/HTTP tests | Passed; 58 discovered tests, with the PostgreSQL-specific case run separately |
| Python lint, static repository checks and dependency audit | Passed |
| API Docker build | Passed |
| PostgreSQL migrations, RLS and concurrent purchase idempotency | Passed |
| Studio type checking, production build and dependency audit | Passed |
| Flutter analysis and 12 widget/workflow tests | Passed on Linux and macOS |
| iOS simulator debug build | Passed; simulator archive uploaded |
| Android debug build | Passed; APK uploaded |
| Real API Android emulator flow | Passed: registration, profile setup, inventory seeding, shopping purchase, seven-dinner planning, cooking confirmation, data export and account deletion |

## CI billing interruption

[The earlier correction run](https://github.com/FilippoCinotti/EatMe/actions/runs/34704386990) failed before executing any steps. The owner supplied GitHub's annotation confirming that recent account payments had failed or the spending limit needed increasing. On the owner's request, the Android job was retried and passed the entire workflow, including the corrected real API integration test. Only the remaining failed jobs were then retried, preserving the successful Android result. The earlier billing failures are not application test results.

The TypeScript lockfile in `bdd6175` is the exact file generated and successfully installed by the preceding CI run. Its temporary lock-resolution step has been removed; subsequent runs use `npm ci`. The application source and native projects are unchanged from the successfully compiled revision.

## Interface review

The light and dark shopping screens were inspected at 390 × 844 with 1.6× text scaling using real fonts. No overflow or clipped controls were observed. These are interface review images, not store marketing screenshots. Two additional tests verify that all four navigation destinations remain inside an unobstructed foldable display region at 1.6× text scaling. The exact formatter output for the new test file is included in the runner correction.

## Local verification limits

The local workspace runs 58 Python tests with three environment-specific skips: two FastAPI adapter tests and one PostgreSQL case. Those adapters run in the dependency-equipped CI jobs. Local Python parsing does not establish Flutter, TypeScript, native or database compatibility.

## Release gates

CodeQL cannot upload its results because GitHub reports that Code scanning is not enabled for this repository. The workflow remains enabled; the repository owner must configure the required feature and obtain a successful scan before release.

Live Supabase/Apple/Google credentials, provider configuration, store purchase sandboxes, scientific publication review, physical-device lifecycle tests, signing and hosted operator-specific legal/support pages remain external release prerequisites. RAD and other unreviewed medical profiles remain unavailable. Debug artifacts do not constitute signed store releases.

Record the final tested application commit and close every implementation, verification and deployment gate before describing a release as store-ready.
