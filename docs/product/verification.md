# Verification report

## Verified foundation

The initial foundation passed API, PostgreSQL, studio and Android/iOS debug CI on commit `e5bdb7b6557794cf327c8e0f3d3c783c2a61a870`. The report is historical and does not validate later application additions.

## Application checks

Commit `db8a4f863ec92102feba84886700509981db87c9` passed all 49 API tests in the dependency-equipped CI environment, including FastAPI. PostgreSQL migrations/RLS and the studio build passed. Mobile formatting and worker lint required fixes.

Commit `b6fb9c3910c55aeb8bbbc20279fc4c09d1417ba5` passed API tests, PostgreSQL and the expanded English studio build. CI identified a Flutter navigation syntax error and an import formatting issue, which are being corrected. Native runners and the Flutter lockfile were generated in CI and retrieved for review.

The local environment runs the Python domain/HTTP tests but does not contain Flutter, FastAPI or PostgreSQL. Two FastAPI tests are skipped locally and run in CI. Do not describe local static parsing as a native platform build.

## Outstanding gates

CodeQL is blocked until repository Code scanning is enabled. Live provider credentials, scientific publication review, device/OAuth/subscription lifecycle tests, store signing and public release resources require staging/owner configuration. This report must be updated with the final validated commit before any release is declared ready.
