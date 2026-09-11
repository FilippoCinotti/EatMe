# 0008: Isolated AI provider adapter

Status: accepted for the application implementation.

## Decision

Centralize prompts and schemas in the server. Treat provider responses as untrusted candidates. Revalidate canonical ingredients and dietary constraints before use. Keep development fixtures explicit and production credentials server-side.

## Consequences

Validate this boundary through domain and platform tests. Revisit the decision when measured scale, reliability or product requirements justify a change; record a new decision rather than silently changing the architecture.
