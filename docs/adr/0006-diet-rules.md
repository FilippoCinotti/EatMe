# 0006: Versioned data-driven dietary rules

Status: accepted for the application implementation.

## Decision

Store dietary definitions and effective rule versions in the database. Publish only reviewed rules. Reject unsupported operators and unknown ingredients. Clinical profiles require explicit consent and approved evidence; no hardcoded invented RAD rule is permitted.

## Consequences

Validate this boundary through domain and platform tests. Revisit the decision when measured scale, reliability or product requirements justify a change; record a new decision rather than silently changing the architecture.
