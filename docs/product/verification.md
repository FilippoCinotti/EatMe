# Verification report

## Application validation

The foundation-only results are superseded by application checks. The latest published implementation is `48669f134397c8e0da51d55345b9a32904ab49af`.

[Application CI](https://github.com/FilippoCinotti/EatMe/actions/runs/34689449901) verifies the following:

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
| Real API Android emulator flow | Blocked before emulator launch by exhausted runner disk space; the runner preparation now removes unused preinstalled SDKs before building |

The light and dark shopping screens were inspected at 390 × 844 with 1.6× text scaling using real fonts. No overflow or clipped controls were observed. These are interface review images, not store marketing screenshots. Two additional tests verify that all four navigation destinations remain inside an unobstructed foldable display region at 1.6× text scaling. The exact formatter output for the new test file is included in the runner correction.

## Local verification limits

The local workspace runs 58 Python tests with three environment-specific skips: two FastAPI adapter tests and one PostgreSQL case. Those adapters run in the dependency-equipped CI jobs. Local Python parsing does not establish Flutter, TypeScript, native or database compatibility.

## Release gates

CodeQL cannot upload its results because GitHub reports that Code scanning is not enabled for this repository. The workflow remains enabled; the repository owner must configure the required feature and obtain a successful scan before release.

Live Supabase/Apple/Google credentials, provider configuration, store purchase sandboxes, scientific publication review, physical-device lifecycle tests, signing and hosted operator-specific legal/support pages remain external release prerequisites. RAD and other unreviewed medical profiles remain unavailable. Debug artifacts do not constitute signed store releases.

Record the final tested application commit and close every implementation, verification and deployment gate before describing a release as store-ready.
