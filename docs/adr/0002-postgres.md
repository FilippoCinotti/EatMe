# 0002: PostgreSQL for production

Status: accepted for the application implementation.

## Decision

Use PostgreSQL and Supabase-compatible row policies in production. Keep SQLite only for explicit local development. Domain SQL uses portable statements and integer quantities; CI separately validates PostgreSQL permissions and transaction behavior.

## Consequences

Validate this boundary through domain and platform tests. Revisit the decision when measured scale, reliability or product requirements justify a change; record a new decision rather than silently changing the architecture.
