# Diet and recommendation engine

The engine applies hard constraints before ranking. Unknown ingredients, known allergens, declared traces, intolerances, explicit exclusions and unavailable rules block the affected candidate. A flexible lifestyle preference can produce a warning; it cannot relax a hard clinical or allergen constraint.

Published diet versions have effective intervals and monotonically increasing versions. Assignments select an explicit strictness. Medical profiles additionally require evidence references, review metadata and versioned consent. RAD remains unavailable until qualified reviewers supply and publish its actual rules. Unsupported operators are rejected instead of being silently ignored.

Ranking combines usable inventory coverage, approaching dates, diet preferences and preparation time. Feedback learning is opt-in. Cuisine and time preferences affect ordering/filtering after safety validation. Explanations and recommendation traces describe actual inputs and component scores. They are not clinical health scores.

Selected household diners require membership and sharing consent. Their constraints are combined; the API does not return another diner's health profile as an explanation. Cooking previews include participant, profile, rule and batch versions. Confirmation runs in a transaction and rejects stale or insufficient allocations. Best-before dates are not treated as safety guarantees.
