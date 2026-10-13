# Supabase authentication emails

EatMe+ uses the branded templates in `supabase/templates` for the two email/password flows exposed by the mobile app:

- account confirmation (`confirmation.html`);
- password recovery (`recovery.html`).

The templates keep Supabase's `{{ .ConfirmationURL }}` variable and use the public full EatMe+ logo (`apps/public/public/eatme-plus-logo.png`). The raster asset is deliberately used instead of SVG for broad email-client compatibility. The `alt` text keeps the brand readable when remote images are blocked. The messages contain no tracking pixels or user profile data.

## Hosted project setup

Supabase reads `supabase/config.toml` during local development. Hosted projects do not deploy email templates through database migrations: copy each subject and HTML body into **Authentication → Email Templates** in the Supabase Dashboard.

In **Authentication → URL Configuration**, keep `com.filippocinotti.eatme://login-callback` in the redirect allow list. Email confirmation and password recovery both pass this exact redirect from the mobile client. Do not replace it with a wildcard in production.

After changing a hosted template, verify both flows with a disposable address on a release-like build. If a custom SMTP provider enables link tracking, disable it for authentication messages because rewritten links can break Supabase verification URLs.
