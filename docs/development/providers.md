# Provider configuration

## Authentication and PostgreSQL

Use Supabase JWT authentication outside development. Configure `SUPABASE_URL`, server `DATABASE_URL` and the mobile publishable key. Apply all migrations in filename order through a privileged migration connection; give the API database login membership in `eatme_backend`. Never ship that password or a service-role key to the device.

Allow the OAuth redirect `com.filippocinotti.eatme://login-callback` in Supabase and configure Apple/Google provider credentials in their consoles. Email verification and password recovery use the same redirect. `SUPABASE_SERVICE_ROLE_KEY` is server-only and enables identity deletion. Validate the complete provider lifecycle, including Apple token revocation, in staging before release.

## Open Food Facts
## Sign in with Apple lifecycle

Enable Sign in with Apple for the native App ID `com.filippocinotti.eatme` and in the Xcode signing profile. Create an associated Services ID for Android web authentication. Register the HTTPS return URL `https://YOUR_API_HOST/api/v1/auth/apple/callback` with Apple and use that exact URL in the mobile `APPLE_ANDROID_CALLBACK_URL`. Set the Services ID in both the mobile and server `APPLE_ANDROID_CLIENT_ID`.

Configure both audiences in Supabase's Apple provider. The mobile client generates and validates the state and nonce, then supplies the ID token to Supabase. It sends the one-time authorization code to the API, which verifies the Apple identity against the authenticated Supabase account before storing an encrypted refresh token for revocation.

Set server-only `APPLE_TEAM_ID`, `APPLE_KEY_ID` and `APPLE_PRIVATE_KEY` using the Apple signing key. Set `APPLE_CLIENT_ID` to the native App ID. The server generates short-lived client secrets for each audience. An optional `APPLE_CLIENT_SECRET` is a pre-generated native secret and requires operator-managed rotation. Never put the private key or client secret into Flutter configuration. `SUPABASE_SERVICE_ROLE_KEY` is required for verified identity lookup and deletion; `MEDIA_ENCRYPTION_KEY` also protects stored Apple refresh tokens.

Before launch, test first sign-in, returning sign-in, cancelled sign-in, email relay, renewed authorization, account deletion and token revocation on both platforms. A simulator build alone does not verify provider console configuration. [Supabase Apple guide](https://supabase.com/docs/guides/auth/social-login/auth-apple).

## Product lookup

Set `PRODUCT_CONTACT` to an operational contact address. The adapter uses the current v3.6 product endpoint, validates barcode check digits, caps response size and caches product data for seven days. It displays attribution and does not contribute uploaded images to the public database. Packaged products remain unreviewed ingredients until their composition is curated.

Respect provider rate limits and complete the required usage registration. Review ODbL obligations for the resulting product database. [Official API documentation](https://openfoodfacts.github.io/openfoodfacts-server/api/).

## Assisted processing

Set `AI_PROVIDER=openai`, `AI_API_KEY`, `AI_MODEL`, `AI_MONTHLY_LIMIT`, `MEDIA_DIRECTORY` and a stable `MEDIA_ENCRYPTION_KEY`. Generate an encryption key using `python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"` and store it in a secret manager. All API replicas and workers must use the same private media volume and encryption key. Back it up separately from encrypted media.

The adapter uses structured outputs, a versioned prompt, bounded responses and server-side validation. Health-profile fields are excluded from provider requests. Model output cannot publish scientific rules or write stock directly. Photo and receipt jobs require user confirmation. Recipe drafts must pass canonical ingredient and dietary validation when saved. [Structured outputs](https://developers.openai.com/api/docs/guides/structured-outputs).

`AI_PROVIDER=development` is an explicit fixture mode and is rejected outside development. Fixture results are visibly labelled. It tests job flow, not recognition accuracy.

## Subscriptions

`REVENUECAT_SECRET_KEY` remains server-only. Configure native SDK publishable keys separately, product offerings in RevenueCat and products in each store. The API verifies entitlements against RevenueCat instead of trusting device purchase assertions. No price is hardcoded. Decide and document the actual paid capability policy before enabling a paywall; the basic manual workflows remain available by default.

## Availability controls

Administrators can disable configured integrations using feature flags. An enabled flag does not create missing credentials or grant an entitlement. Staging must test timeouts, unavailable providers, quota exhaustion, cancellation, malformed output, expired images and retries without duplicate stock.
