# 0003: FastAPI at the production HTTP boundary

Status: accepted for the application implementation.

## Decision

Use FastAPI for request validation, OpenAPI and production hosting. A dependency-light local HTTP adapter invokes the same router and services. Neither adapter duplicates business rules.

## Consequences

Validate this boundary through domain and platform tests. Revisit the decision when measured scale, reliability or product requirements justify a change; record a new decision rather than silently changing the architecture.
