# Production infrastructure and operations

This document separates code-ready controls from owner/provider actions that cannot be truthfully completed without account access. The definitive product domain is `eatmeapplication.com`.

## Environment contract

Maintain distinct development, internal-beta/staging and production environments. A mobile build, API, Guest Web and Supabase project must all belong to the same intended environment. `scripts/check_release_config.py` rejects local, placeholder and unapproved Supabase values for the production mobile build.

| Classification | Settings |
| --- | --- |
| Public config | API URL, Supabase URL, Supabase publishable key, Guest Web URL, RevenueCat mobile publishable key, privacy/terms URLs |
| Server secret | database URL, Supabase service role, Apple server private key, RevenueCat secret, AI key, media encryption key, transactional email credential |
| CI signing secret | App Store Connect API key, distribution identity/password, provisioning profile, temporary keychain password, Apple Team ID |
| Operator config | environment, CORS origins, AI model/budget, retention, feature flags, alert thresholds, release SHA |

Only public config may reach Flutter. Guest Web receives only its public API URL. Migration credentials never reach runtime containers.

## Canonical hosts, DNS and TLS

After the owner selects or confirms a domain, use centralized environment values rather than literals in source. The intended roles are root/product, `guest`, `api`, and optionally private `admin`. Guest RSVP must remain usable without the app installed.

| Action | Service | Value/record required | Where the owner enters it | Sensitive? | Status |
| --- | --- | --- | --- | --- | --- |
| Confirm owned domain/TLD | Domain | `eatmeapplication.com` | Cloudflare | No | Complete |
| Route API | DNS | Host-provider-supplied A/AAAA or CNAME for `api` | Authoritative DNS | No | Blocked |
| Route Guest Web | DNS | Host-provider-supplied A/AAAA or CNAME for `guest` | Authoritative DNS | No | Blocked |
| Verify email domain | DNS | Provider-supplied SPF, DKIM and DMARC records | Authoritative DNS | Some verification tokens | Blocked |
| Issue certificates | Edge/host | Automatic TLS for selected hosts | Hosting provider | Private key managed by provider | Blocked |
| Enforce HTTPS | Edge/host | HTTP redirect, modern TLS; HSTS only after all subdomains are ready | Hosting provider | No | Blocked |

Do not create DNS records until the provider destination is known. Validate each final host with an external TLS checker, redirects disabled for API health, and a separate mobile browser for Guest RSVP.

## Hosting and security boundary

`render.yaml` supplies separate API, worker, Guest, public/legal and Admin services in one region. API and worker use a shared private Supabase Storage bucket rather than an impossible cross-service Render disk. `compose.production.yaml` remains a non-Render deployment option using the same object-storage backend. Do not expose PostgreSQL or migration credentials.

Guest Web and Admin remain isolated. The Guest site must set restrictive CSP/frame/referrer/content-type/cache headers at the deployed edge. Invitation tokens, dietary answers and free text must never enter analytics or unrestricted error events.

The API emits provider-neutral JSON operational events with timestamp, service, environment, release SHA, request ID, route template, status and duration. It does not log request bodies, authorization headers, invitation tokens or profile data. Worker failure events contain only a stable error code.

## Supabase

The approved production project is `ngqetldudwzemdhjprmv`. Six migrations are applied. Every public table has RLS enabled; anonymous DML is revoked and Dinner/Guest tables are inaccessible directly to anon/authenticated roles. The private `eatme-private-media` bucket is configured with a 6.5 MB ciphertext limit and `application/octet-stream` only. The mobile app uses only the publishable key; service-role access stays with API/worker. Before internal invitations, manually verify email delivery and redirects, Apple provider credentials/callbacks, password recovery, account deletion, token revocation and a real authenticated RLS journey.

## AI, media and graceful fallback

AI runs server-side only. The validated rules engine, never model output, decides compatibility. Current controls include explicit consent, canonical-ID structured output, confirmation before inventory writes, 4 MB input and pixel limits, 30-object media quota, monthly per-user request cap, bounded output, short retries, job leases, private encrypted media and expiry cleanup.

Set `AI_PROVIDER=openai`, `AI_API_KEY`, `AI_MODEL` and `AI_MONTHLY_LIMIT` only in the server secret/config store. Keep AI flags disabled until the live acceptance test passes. Manual recipe and Fridge entry remain available when providers fail. Add provider-budget alerts using usage counters/provider billing; never log raw prompts or images.

## Monitoring and alerting

Mobile crash diagnostics use Firebase Crashlytics project `eatme-project`. Collection is Release-only, and application code attaches no recipe, food, dietary, health, image, authentication or guest metadata. An uptime service should independently probe Guest Web and `/api/v1/health`; Render health checks alone do not prove alert delivery. Required log scrubbing includes authorization/cookies, guest tokens, Apple/Supabase tokens, medical/dietary fields, notes, images and all credentials.

Minimum grouped alerts:

- API or Guest Web unreachable;
- sustained API 5xx/latency or database failures;
- mobile/web crash spike by release;
- worker queue age/retries/failures;
- AI failure/quota/budget anomaly;
- email delivery failure;
- RevenueCat verification/webhook failure.

The owner dashboard should answer whether the app is crashing, API and Guest Web are up, jobs and email work, purchases verify, workers are stuck and AI usage is abnormal. External tools are preferred over a new custom product surface.

## Backup and restore

Enable Supabase/PostgreSQL backups appropriate to the plan, retain the media encryption key under separate access control, and back up private media only when its retention policy requires it. Guest temporary data and expired recognition media must not be resurrected beyond policy. Before public launch, restore into an isolated environment and verify tenant/RLS isolation, migration state and deletion retention. TestFlight requires a documented blocker if this rehearsal is not yet complete.

## Production smoke test

Do not invite internal testers until all steps produce recorded evidence: Guest Web opens over HTTPS; API health and database work; verification email arrives; authentication succeeds; Dinner creates a public RSVP link; a separate browser submits; host receives the response; live Social Import/photo processing works or is intentionally disabled; RevenueCat offering loads; monitoring receives a controlled test event; uptime is healthy; and structured logs contain correlation IDs without secrets.
