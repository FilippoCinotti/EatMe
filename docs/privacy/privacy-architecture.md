# Privacy architecture

Health profile consent, household constraint sharing, assisted processing and analytics are independent choices. Removing allergy/intolerance/medical selections withdraws their active consent record. Household sharing can be disabled without leaving the household. Analytics accept a strict usage-field allowlist and exclude food, recipe and health labels.

Mobile snapshots and outbox entries are encrypted using platform secure storage and partitioned by account. Logout clears personal caches. Offline mutations retain their idempotency keys. Final cooking requires live validation. Server images use authenticated ownership, encryption, metadata stripping and a retention deadline. Operations must run media cleanup continuously and monitor failures.

Exports include profile, inventory, events, cooking, consent, plans, shopping, preferences, feedback, private recipes, processing records and media metadata. Account deletion verifies ownership prerequisites, deletes the identity and removes associated personal records and media. Shared contributions are handled according to the data model and documented release policy. Store subscriptions require separate cancellation.

The Next.js app includes public privacy and deletion-request pages. Before release, the operator must supply its identity/contact, legal basis, hosting region, subprocessors, provider retention, backup retention, rights and support procedure. App Store privacy labels and Google Play Data safety declarations must match the configured deployment, including optional integrations.
