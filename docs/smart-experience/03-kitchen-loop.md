# Kitchen Loop confirmation and shopping review

Existing recipe completion already allocates usable lots, accepts manual quantity overrides, checks participant/profile and lot versions, and commits consumption and leftovers atomically with an idempotency key. This change labels each preview amount as estimated or manually confirmed, and records consumed portions, preparation date, leftover location and date provenance. Frozen leftovers do not receive an invented use date; fridge dates remain explicitly suggested. Date validation happens before consumption, so invalid dates roll back the operation.

Plan and recipe shopping actions now preview proposed missing ingredients before a single explicit confirmation. Acceptance supplies shopping, stock and plan versions: intervening edits produce a conflict instead of changing the approved proposal. Recalculation preserves checked items, subtracts their confirmed quantities, and leaves manual rows untouched. A manually edited generated row becomes manual so future generation cannot silently overwrite it. No automatic shopping mutation happens after cooking.

No schema migration; provenance extends existing cooking-session JSON. Existing clients remain compatible. This does not yet consolidate provenance across multiple distinct plans or expose an automatic post-cooking proposal. Those are remaining Smart Experience requirements.

Four regression tests cover atomic leftover storage/provenance and retry, date rollback, read-only shopping preview and checked-row preservation/conflicts, and estimated versus corrected consumption. Existing cooking tests remain required. UI, screenshots and native builds require CI; no production validation is claimed.
