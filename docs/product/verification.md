# Verification report

## Application validation

The foundation-only results are superseded by application checks. The last implementation to receive runtime checks is `bf967a785a9df9bc2c6c3ae1d8bc0c06aae8c442`. Commit `bdd6175a3cfefb314be82adeaf85d9c4b0c86032` adds bounded integration-test waits and the CI-generated TypeScript 7 lockfile; its runtime verification is blocked as described below.

[Application CI](https://github.com/FilippoCinotti/EatMe/actions/runs/34703254730) verifies the following:

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
| Real API Android emulator flow | Emulator launch and app startup passed; the test reached shopping but raced the checkbox response before locating the purchase button. Bounded waits for rendered network results are now included for the next run |

## Current CI blocker

[The correction run](https://github.com/FilippoCinotti/EatMe/actions/runs/34704386990) failed every job before executing any steps. Retrying the Android job produced the same result within two seconds, with no runner logs. The connected GitHub interface exposes an annotation count but cannot read its diagnostic text. No billing, quota or runner cause has been confirmed. The owner must inspect the run's annotation in GitHub Actions, resolve the reported account or runner issue, and rerun the application workflow. Do not interpret this infrastructure failure as a test result or mark the Android integration gate as passed.

The TypeScript lockfile in `bdd6175` is the exact file generated and successfully installed by the preceding CI run. Its temporary lock-resolution step has been removed; subsequent runs use `npm ci`. The application source and native projects are unchanged from the successfully compiled revision.

## Interface review

The light and dark shopping screens were inspected at 390 × 844 with 1.6× text scaling using real fonts. No overflow or clipped controls were observed. These are interface review images, not store marketing screenshots. Two additional tests verify that all four navigation destinations remain inside an unobstructed foldable display region at 1.6× text scaling. The exact formatter output for the new test file is included in the runner correction.

## Local verification limits

The local workspace runs 58 Python tests with three environment-specific skips: two FastAPI adapter tests and one PostgreSQL case. Those adapters run in the dependency-equipped CI jobs. Local Python parsing does not establish Flutter, TypeScript, native or database compatibility.

## Release gates

CodeQL cannot upload its results because GitHub reports that Code scanning is not enabled for this repository. The workflow remains enabled; the repository owner must configure the required feature and obtain a successful scan before release.

Live Supabase/Apple/Google credentials, provider configuration, store purchase sandboxes, scientific publication review, physical-device lifecycle tests, signing and hosted operator-specific legal/support pages remain external release prerequisites. RAD and other unreviewed medical profiles remain unavailable. Debug artifacts do not constitute signed store releases.

Record the final tested application commit and close every implementation, verification and deployment gate before describing a release as store-ready.
