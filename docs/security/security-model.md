# Security model

## Authorization

JWT verification checks signature, supported algorithm, issuer, audience, expiry and authenticated role. Backend service methods verify membership and write role; client UUIDs are not authority. Private recipe queries filter ownership. Direct mobile database writes are denied. New application tables are accessible only through the restricted backend role and authorized API.

## Integrity

Mutations use UUID idempotency keys bound to a request hash. Reusing a key for different input returns a conflict. Versions prevent stale updates. Household mutations serialize in PostgreSQL, while SQLite serializes development writes. Cooking confirms exact allocations and fails atomically on stale versions or missing quantities.

## Untrusted content

All SQL values are parameterized. Import URLs must use HTTPS and resolve exclusively to public addresses; the connection uses the checked address with TLS hostname verification. Redirects and response sizes are bounded. Media files are decoded and re-encoded. AI schemas, canonical identifiers and permissions are validated before use.

## Dinner capability links

Guest invitations use 256-bit random URL-safe capabilities. Only SHA-256 digests are persisted; plaintext tokens are returned once when the host creates or rotates a link. Rotation invalidates the previous capability, cancellation or completion revokes active links, and expired, revoked and unknown links return the same public error. Public reads disclose only the addressed guest's event and questionnaire data. Per-client and per-capability limits are enforced in both a bounded process limiter and a database-backed window shared by API replicas.

The guest site sends no credentials, embeds no third-party resources, uses `no-store`, `noindex`, a no-referrer policy and a restrictive CSP. Dinner tables have RLS enabled with no `anon` or `authenticated` policies; public access is mediated exclusively by the restricted backend.

## Operations

Keep production secrets in a secret manager, require TLS, restrict migration credentials, suppress body/token logging and apply gateway rate limits. Configure trusted proxy forwarding deliberately. Use encrypted database backups with a defined deletion retention policy. Run dependency audit, PostgreSQL isolation tests, CodeQL and physical-device permission/security tests before release.
