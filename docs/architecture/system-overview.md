# System overview

Flutter owns interaction, navigation, device permissions and bounded encrypted offline snapshots. The Python API owns identity verification, membership, consent, dietary validation and all mutations. PostgreSQL is the production database; SQLite is an explicit local development adapter. A worker consumes durable database jobs. The Next.js studio proxies authenticated editorial requests through HTTP-only sessions.

## Boundaries

`Service` composes inventory/cooking, household, planning, content, governance, intelligence and lifecycle services. Transactions are short and synchronous. External requests are performed outside inventory write transactions. Quantity arithmetic uses integer thousandths; cooking revalidates requirements and versions at confirmation.

Provider responses are untrusted. HTTPS imports validate public addresses, pin the validated connection, preserve TLS hostname checks, cap responses and restrict redirects. Processing never writes inventory until a user confirms corrected candidates. Clinical publication is independent of AI processing.

## Environments

Development permits local credentials, fixture content and SQLite. Staging/production require Supabase and PostgreSQL. Live integrations require server-side keys and configured feature availability. Release mobile builds reject local authentication and HTTP endpoints. CI validates adapters separately and builds both native targets.
