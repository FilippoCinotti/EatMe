# 0007: Deterministic recommendations

Status: accepted for the application implementation.

## Decision

Filter hard constraints before scoring availability, approaching dates, preferences and time. Persist explainable traces and input versions. Learning from recipe feedback is opt-in and never infers medical conditions.

## Consequences

Validate this boundary through domain and platform tests. Revisit the decision when measured scale, reliability or product requirements justify a change; record a new decision rather than silently changing the architecture.
