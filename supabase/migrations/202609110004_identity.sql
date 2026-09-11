BEGIN;
-- Authentication may precede onboarding, so this encrypted lifecycle record is not profile-dependent.
CREATE TABLE IF NOT EXISTS identity_tokens (
 user_id TEXT NOT NULL, provider TEXT NOT NULL, ciphertext TEXT NOT NULL,
 PRIMARY KEY(user_id,provider)
);
ALTER TABLE identity_tokens ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON identity_tokens FROM anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON identity_tokens TO eatme_backend;
CREATE POLICY backend_application ON identity_tokens FOR ALL TO eatme_backend USING(TRUE) WITH CHECK(TRUE);
INSERT INTO schema_versions(version) VALUES ('0004') ON CONFLICT DO NOTHING;
COMMIT;
