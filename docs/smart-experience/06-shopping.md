# Partial shopping purchases

The individual Put in Fridge action now asks the quantity actually purchased. A partial purchase adds only that quantity to inventory and retains the outstanding amount on the list, unchecked and with an incremented version. The card shows remaining and purchased amounts. A full or larger purchase closes the line. Bulk purchase keeps its existing full-quantity behavior.

The existing household transaction and operation key make inventory insertion and remainder updates atomic and idempotent. Inventory event provenance records the shopping line ID and requested amount; partial totals are derived from those recorded events, not estimated. Existing canonical units apply, including whole pieces. Recalculation retains partially purchased generated rows and their history.

No schema migration. Two regression tests cover 500 g requested / 300 g purchased / 200 g outstanding, duplicate retries, stale versions, completing the remainder, and preserving partial lines during recalculation. Local test success does not replace CI or device review. Realtime collaboration and full cross-plan consolidation remain separate requirements.
