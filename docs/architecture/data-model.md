# Data model

## Identity and sharing

Profiles use authentication UUIDs. A profile selects a current household while membership can span several households. Households have one owner and owner/member/viewer roles. Invitations store hashed random tokens, expiration and acceptance state. Constraint-sharing consent is separate from membership.

## Food and cooking

Foods and recipes store canonical, versionable structured data. Inventory stores separate batches, exact integer quantities, location, date type, provenance and version. Metadata stores product/barcode/lot/purchase details without changing the baseline batch layout. Events record inventory deltas. Cooking sessions record the revalidated allocation snapshot. Leftover state tracks remaining portions separately from the original preparation record.

## Planning and content

Shopping lines have quantities, check state, source keys and versions. Plans are personal records scoped to a household and contain dated meal slots and selected diners. Private recipes have ownership markers and are excluded from other users' catalogs. Favorites and feedback are personal.

## Governance and jobs

Governed content has a subject, revision, workflow state, author and independent reviewer. Published diet versions reference evidence and effective dates. Processing jobs persist state, attempts, lease, payload, result and confirmation. Media records reference encrypted private objects with retention deadlines. Operation records bind an idempotency key to a request hash and committed response.

## Migrations

`0001` defines the initial inventory/cooking schema, `0002` applies restricted roles and row policies, and `0003` adds the application domains. The local adapter uses equivalent additive SQL. Production migrations are immutable and checksum-verified by `scripts/migrate.py`.
