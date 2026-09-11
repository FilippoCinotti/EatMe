# EatMe application completion plan

This plan implements the release scope in phases 1–8 of the product specification.
Items explicitly described as future integrations, including HealthKit, Health
Connect, smart appliances and restaurant menus, remain inactive extension points.

## Acceptance criteria

1. Every exposed action completes a persisted, authorized workflow and handles
   loading, empty, offline, validation and failure states.
2. Allergy and published medical constraints are enforced before recommendations,
   imports, substitutions, planning and cooking, including selected participants.
3. Barcode, photo and receipt workflows expose provenance and uncertainty and
   require review before inventory writes. Provider failures preserve manual entry.
4. Plans aggregate shopping deficits against usable stock exactly once. Purchases,
   cooking and leftover consumption are transactional and idempotent.
5. Household roles, invitation expiry, ownership transfer and account deletion
   protect private data and shared records.
6. Encrypted local persistence supports cold starts and a bounded mutation outbox;
   conflicts require reconciliation rather than silently overwriting quantities.
7. Administration supports draft, independent review, publication and audit for
   scientific content, diet rules and expiry guidance.
8. Native projects, locked dependencies, store assets, permission descriptions,
   privacy documents and debug/release instructions are versioned in English.
9. Unit, authorization, workflow, API, database, widget, integration and platform
   build checks provide evidence for completion claims.

## Work streams

| Work stream | Deliverables |
| --- | --- |
| Daily use | Favorites, feedback, preferences, search, richer recipe details, shopping, planner, leftovers, waste/cost insights |
| Shared use | Invitations, roles, switching, selected diners, shared constraints, synchronization, notifications |
| Food intelligence | Product providers, canonical aliases, nutrition units, substitutions, import, scans and asynchronous processing |
| Scientific governance | Evidence records, approved retrieval, recall matching, diet/expiry versioning, reports, admin roles and audit |
| Reliability | Encrypted cache/outbox, pagination, bounded jobs, rate limits, account lifecycle, observability and feature entitlements |
| Release | Native runners, app assets, privacy manifests, signing configuration, CI artifacts and simulator guide |

## External release prerequisites

Implementation continues without credentials. Live Supabase/OAuth, AI and optional
billing integrations require owner-controlled accounts and secrets for final live
verification. Store submission requires registered app identifiers, signing,
developer accounts, hosted service/privacy URLs and completed store declarations.
Clinical rule sets, including RAD, require qualified scientific review before
publication. Tests and development fixtures never substitute for that review.

These prerequisites must be reported accurately; they do not justify leaving the
corresponding software workflows unimplemented.
