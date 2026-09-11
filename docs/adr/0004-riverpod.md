# 0004: Riverpod for application state

Status: accepted for the application implementation.

## Decision

Use Riverpod for session, catalog, inventory and recommendation state. Scope feature state to screens and route providers. Clear account-specific state on logout and identity changes.

## Consequences

Validate this boundary through domain and platform tests. Revisit the decision when measured scale, reliability or product requirements justify a change; record a new decision rather than silently changing the architecture.
