# Deployment runbook

## Prepare a staging environment

1. Use a separate Supabase project and restricted database login. Apply all six immutable migrations using `MIGRATION_DATABASE_URL` and `python scripts/migrate.py`. Grant the API login membership in `eatme_backend`; it must not be the migration owner, a superuser or a role with `BYPASSRLS`.
2. Link the deployment to Supabase project `ngqetldudwzemdhjprmv` (`https://ngqetldudwzemdhjprmv.supabase.co`). Configure asymmetric JWT signing, email delivery, redirect URLs and Google/Apple identities as described in the provider guide. Supply the public publishable/anon key to the mobile build, and keep `SUPABASE_SERVICE_ROLE_KEY` only in the API/worker secret environment for identity deletion.
3. Use the root `render.yaml` Blueprint with the existing GitHub-linked Render account. It defines separate API, worker, Guest, public/legal and Admin services in Frankfurt. Automatic deploys remain off during release freeze; deploy the reviewed branch head manually, record its SHA, and switch the Blueprint branch to `main` only after that exact head is merged.
4. Set the Blueprint's `sync: false` values in Render's secret environment. Do not supply the migration credential to runtime services. Keep `AI_PROVIDER` empty until its provider and disclosure are configured; never use `development` in staging or production.
5. API and worker do not share a Render persistent disk. Both use `MEDIA_STORAGE_BACKEND=supabase`, the private `eatme-private-media` bucket and the same stable `MEDIA_ENCRYPTION_KEY`. Provision/verify the bucket with `scripts/provision_supabase_storage.py` from a trusted operator environment. The object payload remains Fernet-encrypted before upload; the service-role key never reaches Flutter or either web client.
6. Set `GUEST_APP_URL`, `GUEST_INVITE_EXPIRY_HOURS_AFTER_EVENT` and `GUEST_TEMP_DATA_RETENTION_DAYS` on the API. The guest site and API must use HTTPS. Route the guest site without third-party redirects or referrer leakage.
7. Route `eatmeapplication.com` and `www` to the public service, `api` to API, `guest` to Guest and `admin` to the editorial studio. Add each custom domain in Render before creating its Cloudflare record. Use proxied DNS only after Render has issued origin certificates; then select Full (strict) TLS. Enable HSTS only after every hostname succeeds over HTTPS.
8. Set `PRIVACY_OPERATOR`, `PRIVACY_CONTACT` and `SUPPORT_CONTACT` only to owner-approved values. The public service deliberately keeps registration/launch language closed while those values are absent.

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

The TestFlight signing and upload procedure is in [testflight.md](testflight.md). Infrastructure ownership, DNS/TLS, monitoring, AI limits and external blockers are tracked in [production-readiness.md](production-readiness.md).
