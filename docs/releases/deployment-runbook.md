# Deployment runbook

## Prepare a staging environment

1. Use a separate Supabase project and restricted database login. Apply all five immutable migrations using `MIGRATION_DATABASE_URL` and `python scripts/migrate.py`. Grant the API login membership in `eatme_backend`; it must not be the migration owner, a superuser or a role with `BYPASSRLS`.
2. Configure Supabase asymmetric JWT signing, email delivery, redirect URLs and Google/Apple identities as described in the provider guide. Supply `SUPABASE_SERVICE_ROLE_KEY` only to the API/worker secret environment for identity deletion.
3. Build the API image from the reviewed commit: `docker build -t YOUR_REGISTRY/eatme-api:COMMIT services/api`. Push it to your registry and record its immutable digest as `EATME_IMAGE`.
4. Create a private `.env.production` from `.env.example`. Set the PostgreSQL connection, Supabase URL, stable encryption key, editorial bootstrap account and enabled integration credentials. Do not supply the migration credential to runtime containers. Keep `AI_PROVIDER` empty until its provider and disclosure are configured; never use `development` in staging or production.
5. Build the guest image from `apps/guest` with the public HTTPS API URL as `NEXT_PUBLIC_API_URL`, record its digest as `EATME_GUEST_IMAGE`, then run `docker compose -f compose.production.yaml up -d`. The example binds the API and guest site to loopback and shares encrypted media between API and worker. Place an HTTPS reverse proxy in front of them with request limits and trusted proxy forwarding. Do not enable request-body, authorization-header or invitation-URL logging.
6. Set `GUEST_APP_URL`, `GUEST_INVITE_EXPIRY_HOURS_AFTER_EVENT` and `GUEST_TEMP_DATA_RETENTION_DAYS` on the API. The guest site and API must use HTTPS. Route the guest site without third-party redirects or referrer leakage.
7. Build the studio with `npm ci --ignore-scripts` and `npm run build`; run `npm start` behind HTTPS. Set `EATME_API_URL`, Supabase server authentication values, `PRIVACY_OPERATOR` and `PRIVACY_CONTACT` in its runtime environment. Publish `/privacy`, `/terms`, `/support` and `/delete-account`, and complete operator-specific privacy/terms information before public registration.

## Validate before opening registration

Create separate owner, member, viewer, editor and reviewer staging accounts. Confirm sharing is opt-in, viewer mutations fail, invite revocation works, and one editor cannot publish their own revision. Import reviewed food and recipe content before onboarding public users; production startup does not seed the demonstration catalog. Medical and RAD profiles require qualified independent review and current evidence.

Exercise a complete mobile flow against staging: authentication, profile, stock, planning, shopping purchase, cooking confirmation, leftovers, export, household changes and account deletion. Exercise provider timeouts, cancelled image jobs and offline conflicts. For Apple accounts, verify token revocation and Supabase identity removal; for purchases, test purchase, restore, expiration and cancellation in each store's sandbox.

Create a Dinner, rotate and revoke an invite, answer without login in all six guest locales, edit and delete the answer, verify the unanswered status never reports “works for everyone”, and confirm a peanut-allergy fixture blocks a peanut recipe.

Copy the mobile public configuration template to `apps/mobile/config/production.json`, fill its deployment values and run:

```bash
python scripts/check_release_config.py apps/mobile/config/production.json
```

This command checks configuration shape and rejects accidental secret keys. It does not contact providers or validate legal, scientific or store approvals. Keep the mobile configuration consistent with the release notes and store environment.

## Operations and recovery

Monitor API availability and error rates, database connections, processing jobs older than their lease, repeated job failures, pending account deletions, media cleanup and container restarts. The API health endpoint confirms the HTTP process; separately probe an authenticated database operation. The worker cleans expired media and retries pending identity deletion every minute. Alert on growing pending queues rather than treating a running container as proof of processing.

Back up PostgreSQL and the stable encryption key using separate access controls. Back up private media only if the backup retention policy honors its short lifetime. Run a restore rehearsal in an isolated environment before release. Record restore time and verify tenant isolation after restoration. Restrict database, media and provider credentials to the smallest required service roles.

Roll back the application by redeploying the previous immutable image and studio build. Applied migrations are immutable; do not run destructive reverse migrations. If a rollback cannot read the new schema, restore a rehearsed backup into a separate database and review data loss before switching traffic. Use server feature flags to disable optional integrations while investigating an incident. Retain the tested commit, mobile build numbers and migration checksums in each release record.
