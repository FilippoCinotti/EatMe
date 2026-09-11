# Security model

## Authorization

JWT verification checks signature, supported algorithm, issuer, audience, expiry and authenticated role. Backend service methods verify membership and write role; client UUIDs are not authority. Private recipe queries filter ownership. Direct mobile database writes are denied. New application tables are accessible only through the restricted backend role and authorized API.

## Integrity

Mutations use UUID idempotency keys bound to a request hash. Reusing a key for different input returns a conflict. Versions prevent stale updates. Household mutations serialize in PostgreSQL, while SQLite serializes development writes. Cooking confirms exact allocations and fails atomically on stale versions or missing quantities.

## Untrusted content

All SQL values are parameterized. Import URLs must use HTTPS and resolve exclusively to public addresses; the connection uses the checked address with TLS hostname verification. Redirects and response sizes are bounded. Media files are decoded and re-encoded. AI schemas, canonical identifiers and permissions are validated before use.

## Operations

Keep production secrets in a secret manager, require TLS, restrict migration credentials, suppress body/token logging and apply gateway rate limits. Configure trusted proxy forwarding deliberately. Use encrypted database backups with a defined deletion retention policy. Run dependency audit, PostgreSQL isolation tests, CodeQL and physical-device permission/security tests before release.
