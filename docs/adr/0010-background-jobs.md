# 0010: Durable database-backed processing jobs

Status: accepted for the application implementation.

## Decision

Use database jobs with leases, version checks, cancellation and bounded retries. Store media separately with private encryption and retention. Processing workers never write inventory without user confirmation.

## Consequences

Validate this boundary through domain and platform tests. Revisit the decision when measured scale, reliability or product requirements justify a change; record a new decision rather than silently changing the architecture.
