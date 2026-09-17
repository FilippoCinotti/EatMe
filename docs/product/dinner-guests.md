# Dinner and guest RSVP

Dinner is a Plan workflow, not a fifth primary destination. A host creates an event, selects household members or guests, shares a private capability link, reviews RSVP state, chooses recipes, and uses the existing Diet-Fit engine before generating servings, shopping and a cooking timeline.

## Participant and invitation contract

- `host` and `household_member` participants link to accounts.
- `saved_guest` records exist only within one household and require prior guest opt-in.
- `temporary_guest` data is event-scoped and expires after the configured post-event retention period.
- Invitation capabilities are generated with at least 256 bits of entropy. The database stores only a SHA-256 digest.
- Create and rotate return plaintext once. List and detail payloads never return the token or digest.
- Rotate, revoke, remove, cancel, complete and expiry all make the old public link unusable.
- Public errors do not distinguish a guessed token from a revoked, expired or cancelled invitation.

## Guest flow

`apps/guest` is a no-login Next.js 16 / React 19 application with English, Italian, Spanish, French, German and Simplified Chinese routes. It collects RSVP, eating style, allergies, intolerances, sensitivities, explicit food avoidances, an optional note and a separate remember opt-in. Guests can review, submit, edit and delete their response.

The public API returns only the event title, time, location and host; the addressed guest; that guest's response; and questionnaire choices. It never returns the household, roster, other responses, inventory, menu or internal identifiers.

## Group Diet-Fit

Dinner calls the same versioned compatibility engine used by recipes and cooking. Results follow this precedence:

1. Any hard conflict: `not_compatible`.
2. Any attending participant without usable answers or consent: `review_required`.
3. Non-blocking warnings: `works_with_notes`.
4. Only a fully answered, conflict-free group: `works_for_everyone`.

The host result identifies affected participants and reason codes but does not echo the allergen or medical value in the aggregate result. Safety status and hard-conflict checks are never an EatMe+ gate. Generated shopping remains governed by the existing planning entitlement.

## Retention and release checks

Server settings:

- `GUEST_APP_URL`: public HTTPS origin used to construct links.
- `GUEST_INVITE_EXPIRY_HOURS_AFTER_EVENT`: active-link grace period, default 24 hours.
- `GUEST_TEMP_DATA_RETENTION_DAYS`: temporary response retention, default 7 days and capped at 90.

Release validation must cover token hashing, rotation and revocation; generic public failures; rate limiting; cross-household denial; RLS denial for direct public clients; unanswered guests; peanut allergy; response edit and delete; remember opt-in and opt-out; six locales; mobile text scaling; the guest production build; and both container images.
