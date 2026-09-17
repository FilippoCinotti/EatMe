BEGIN;
CREATE TABLE IF NOT EXISTS dinners (
 id TEXT PRIMARY KEY, household_id TEXT NOT NULL REFERENCES households(id) ON DELETE CASCADE,
 host_user_id TEXT NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
 title TEXT NOT NULL, starts_at TEXT NOT NULL, timezone TEXT NOT NULL, location TEXT,
 status TEXT NOT NULL CHECK(status IN ('planned','cancelled','completed')),
 data TEXT NOT NULL, version INTEGER NOT NULL DEFAULT 1, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS dinners_host_start ON dinners(host_user_id,starts_at);
CREATE TABLE IF NOT EXISTS dinner_saved_guests (
 id TEXT PRIMARY KEY, household_id TEXT NOT NULL REFERENCES households(id) ON DELETE CASCADE,
 display_name TEXT NOT NULL, data TEXT NOT NULL, consented_at TEXT NOT NULL,
 created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS dinner_participants (
 id TEXT PRIMARY KEY, dinner_id TEXT NOT NULL REFERENCES dinners(id) ON DELETE CASCADE,
 kind TEXT NOT NULL CHECK(kind IN ('host','household_member','saved_guest','temporary_guest')),
 user_id TEXT REFERENCES profiles(user_id) ON DELETE SET NULL,
 saved_guest_id TEXT REFERENCES dinner_saved_guests(id) ON DELETE SET NULL,
 display_name TEXT NOT NULL,
 status TEXT NOT NULL CHECK(status IN ('host','accepted','invited','responded','declined')),
 created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS dinner_participants_event ON dinner_participants(dinner_id,status);
CREATE TABLE IF NOT EXISTS dinner_invitations (
 id TEXT PRIMARY KEY, dinner_id TEXT NOT NULL REFERENCES dinners(id) ON DELETE CASCADE,
 participant_id TEXT NOT NULL UNIQUE REFERENCES dinner_participants(id) ON DELETE CASCADE,
 token_hash TEXT NOT NULL UNIQUE, expires_at TEXT NOT NULL, revoked_at TEXT,
 rotated_at TEXT, created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS dinner_invites_expiry ON dinner_invitations(expires_at);
CREATE TABLE IF NOT EXISTS dinner_guest_responses (
 invitation_id TEXT PRIMARY KEY REFERENCES dinner_invitations(id) ON DELETE CASCADE,
 data TEXT NOT NULL, remembered_guest_id TEXT REFERENCES dinner_saved_guests(id) ON DELETE SET NULL,
 submitted_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS dinner_memories (
 id TEXT PRIMARY KEY, dinner_id TEXT NOT NULL UNIQUE REFERENCES dinners(id) ON DELETE CASCADE,
 household_id TEXT NOT NULL REFERENCES households(id) ON DELETE CASCADE,
 data TEXT NOT NULL, created_at TEXT NOT NULL
);

DO $$ DECLARE relation TEXT; BEGIN
 FOREACH relation IN ARRAY ARRAY[
  'dinners','dinner_saved_guests','dinner_participants',
  'dinner_invitations','dinner_guest_responses','dinner_memories'
 ] LOOP
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',relation);
  EXECUTE format('REVOKE ALL ON public.%I FROM anon, authenticated',relation);
  EXECUTE format('GRANT SELECT,INSERT,UPDATE,DELETE ON public.%I TO eatme_backend',relation);
  EXECUTE format(
   'CREATE POLICY backend_application ON public.%I FOR ALL TO eatme_backend USING(TRUE) WITH CHECK(TRUE)',
   relation
  );
 END LOOP;
END $$;

-- Capability tokens are accepted only by the API, which stores only SHA-256
-- token digests. There are deliberately no anon/authenticated policies.
INSERT INTO schema_versions(version) VALUES ('0005') ON CONFLICT DO NOTHING;
COMMIT;
