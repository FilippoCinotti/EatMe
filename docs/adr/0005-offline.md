# 0005: Bounded encrypted offline persistence

Status: accepted for the application implementation.

## Decision

Use bounded platform-encrypted snapshots and a durable outbox partitioned by account. Each queued mutation retains its UUID and household context. Do not queue cooking confirmation or publish scientific content offline. A conflict requires explicit reconciliation. Larger catalog datasets can migrate behind this storage boundary without changing server authority.

## Consequences

Validate this boundary through domain and platform tests. Revisit the decision when measured scale, reliability or product requirements justify a change; record a new decision rather than silently changing the architecture.
