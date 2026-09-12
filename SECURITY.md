# Security policy

Report vulnerabilities privately through GitHub private vulnerability reporting when enabled, or through the repository owner's configured security contact. Do not put access tokens, health profiles or exploit data from real accounts in public issues.

The API is the authorization and transaction boundary. Client-provided household identifiers, role assertions, prices and AI output are not trusted. PostgreSQL clients have no direct write permissions. Production uses Supabase JWT verification and a restricted database role. Development credentials and SQLite are prohibited outside development.

Security-sensitive areas include shared membership, consent withdrawal, cooking concurrency, private media, imports, account deletion and editorial publication. Required release gates are documented in `docs/releases/release-process.md`. CodeQL requires GitHub Code scanning to be enabled for the repository; a disabled repository feature is not a passing scan.
