BEGIN;
-- Application domains added after the initial inventory/cooking schema.
CREATE TABLE IF NOT EXISTS user_preferences (
 user_id TEXT PRIMARY KEY REFERENCES profiles(user_id) ON DELETE CASCADE,
 data TEXT NOT NULL, version INTEGER NOT NULL DEFAULT 1, updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS content_ownership (
 kind TEXT NOT NULL, content_id TEXT NOT NULL, user_id TEXT NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
 household_id TEXT REFERENCES households(id) ON DELETE CASCADE, PRIMARY KEY(kind,content_id)
);
CREATE TABLE IF NOT EXISTS food_aliases (
 alias TEXT NOT NULL, locale TEXT NOT NULL, food_id TEXT NOT NULL REFERENCES foods(id),
 source TEXT NOT NULL, PRIMARY KEY(alias,locale,food_id)
);
CREATE TABLE IF NOT EXISTS food_products (
 id TEXT PRIMARY KEY, barcode TEXT NOT NULL UNIQUE, food_id TEXT REFERENCES foods(id),
 data TEXT NOT NULL, version INTEGER NOT NULL DEFAULT 1, updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS inventory_metadata (
 batch_id TEXT PRIMARY KEY REFERENCES inventory_batches(id) ON DELETE CASCADE,
 data TEXT NOT NULL, confirmed_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS recipe_favorites (
 user_id TEXT NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
 recipe_id TEXT NOT NULL REFERENCES recipes(id) ON DELETE CASCADE, created_at TEXT NOT NULL,
 PRIMARY KEY(user_id,recipe_id)
);
CREATE TABLE IF NOT EXISTS recipe_feedback (
 user_id TEXT NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
 recipe_id TEXT NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
 rating INTEGER NOT NULL CHECK(rating BETWEEN -1 AND 1), reasons TEXT NOT NULL, updated_at TEXT NOT NULL,
 PRIMARY KEY(user_id,recipe_id)
);
CREATE TABLE IF NOT EXISTS household_invitations (
 id TEXT PRIMARY KEY, household_id TEXT NOT NULL REFERENCES households(id) ON DELETE CASCADE,
 created_by TEXT NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
 token_hash TEXT NOT NULL UNIQUE, role TEXT NOT NULL CHECK(role IN ('member','viewer')),
 expires_at TEXT NOT NULL, accepted_by TEXT, accepted_at TEXT, revoked_at TEXT, created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS household_settings (
 household_id TEXT PRIMARY KEY REFERENCES households(id) ON DELETE CASCADE,
 name TEXT NOT NULL, version INTEGER NOT NULL DEFAULT 1, updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS member_permissions (
 household_id TEXT NOT NULL REFERENCES households(id) ON DELETE CASCADE,
 user_id TEXT NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
 share_constraints INTEGER NOT NULL DEFAULT 0 CHECK(share_constraints IN (0,1)),
 consent_version TEXT, updated_at TEXT NOT NULL, PRIMARY KEY(household_id,user_id)
);
CREATE TABLE IF NOT EXISTS shopping_items (
 id TEXT PRIMARY KEY, household_id TEXT NOT NULL REFERENCES households(id) ON DELETE CASCADE,
 food_id TEXT REFERENCES foods(id), label TEXT NOT NULL, quantity_milli BIGINT NOT NULL CHECK(quantity_milli>0),
 unit TEXT NOT NULL CHECK(unit IN ('g','ml','pcs')), category TEXT NOT NULL, checked INTEGER NOT NULL DEFAULT 0,
 source_key TEXT NOT NULL, version INTEGER NOT NULL DEFAULT 1, created_by TEXT,
 created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS shopping_household ON shopping_items(household_id,checked,category);
CREATE TABLE IF NOT EXISTS meal_plans (
 id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
 household_id TEXT NOT NULL REFERENCES households(id) ON DELETE CASCADE,
 start_date TEXT NOT NULL, data TEXT NOT NULL, version INTEGER NOT NULL DEFAULT 1,
 created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS plans_user_date ON meal_plans(user_id,start_date);
CREATE TABLE IF NOT EXISTS leftover_state (
 leftover_id TEXT PRIMARY KEY REFERENCES leftovers(id) ON DELETE CASCADE,
 remaining INTEGER NOT NULL CHECK(remaining>=0), version INTEGER NOT NULL DEFAULT 1,
 updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS leftover_events (
 id TEXT PRIMARY KEY, leftover_id TEXT NOT NULL REFERENCES leftovers(id) ON DELETE CASCADE,
 actor_id TEXT, kind TEXT NOT NULL, servings INTEGER NOT NULL, created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS processing_jobs (
 id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
 household_id TEXT NOT NULL REFERENCES households(id) ON DELETE CASCADE,
 kind TEXT NOT NULL, status TEXT NOT NULL, progress INTEGER NOT NULL DEFAULT 0,
 payload TEXT NOT NULL, result TEXT, error_code TEXT, attempts INTEGER NOT NULL DEFAULT 0,
 available_at TEXT NOT NULL, lease_until TEXT, created_at TEXT NOT NULL, completed_at TEXT,
 confirmed_at TEXT, version INTEGER NOT NULL DEFAULT 1
);
CREATE INDEX IF NOT EXISTS jobs_queue ON processing_jobs(status,available_at,lease_until);
CREATE INDEX IF NOT EXISTS jobs_user ON processing_jobs(user_id,created_at);
CREATE TABLE IF NOT EXISTS media_objects (
 id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
 kind TEXT NOT NULL, storage_key TEXT NOT NULL UNIQUE, mime_type TEXT NOT NULL,
 size_bytes INTEGER NOT NULL, created_at TEXT NOT NULL, expires_at TEXT
);
CREATE TABLE IF NOT EXISTS governed_content (
 id TEXT PRIMARY KEY, kind TEXT NOT NULL, subject_id TEXT NOT NULL,
 revision INTEGER NOT NULL, status TEXT NOT NULL CHECK(status IN ('DRAFT','IN_REVIEW','PUBLISHED','DEPRECATED')),
 data TEXT NOT NULL, created_by TEXT NOT NULL, reviewed_by TEXT, reviewed_at TEXT,
 created_at TEXT NOT NULL, updated_at TEXT NOT NULL, UNIQUE(kind,subject_id,revision)
);
CREATE INDEX IF NOT EXISTS governed_kind_status ON governed_content(kind,status,subject_id);
CREATE TABLE IF NOT EXISTS admin_roles (
 user_id TEXT PRIMARY KEY REFERENCES profiles(user_id) ON DELETE CASCADE,
 role TEXT NOT NULL CHECK(role IN ('support','editor','reviewer','admin','superadmin')),
 updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS data_reports (
 id TEXT PRIMARY KEY, user_id TEXT REFERENCES profiles(user_id) ON DELETE SET NULL,
 kind TEXT NOT NULL, subject_id TEXT NOT NULL, message TEXT NOT NULL, status TEXT NOT NULL,
 created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS notification_preferences (
 user_id TEXT PRIMARY KEY REFERENCES profiles(user_id) ON DELETE CASCADE,
 data TEXT NOT NULL, version INTEGER NOT NULL DEFAULT 1, updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS notification_events (
 id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
 category TEXT NOT NULL, dedup_key TEXT NOT NULL, data TEXT NOT NULL,
 created_at TEXT NOT NULL, read_at TEXT, UNIQUE(user_id,dedup_key)
);
CREATE TABLE IF NOT EXISTS feature_flags (
 name TEXT PRIMARY KEY, enabled INTEGER NOT NULL CHECK(enabled IN (0,1)), updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS subscriptions (
 user_id TEXT PRIMARY KEY REFERENCES profiles(user_id) ON DELETE CASCADE,
 provider TEXT NOT NULL, data TEXT NOT NULL, checked_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS provider_events (
 event_id TEXT PRIMARY KEY, provider TEXT NOT NULL, processed_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS usage_counters (
 user_id TEXT NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
 capability TEXT NOT NULL, period TEXT NOT NULL, used INTEGER NOT NULL DEFAULT 0,
 PRIMARY KEY(user_id,capability,period)
);
CREATE TABLE IF NOT EXISTS analytics_events (
 id TEXT PRIMARY KEY, user_id TEXT REFERENCES profiles(user_id) ON DELETE CASCADE,
 event TEXT NOT NULL, data TEXT NOT NULL, created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS analytics_user_date ON analytics_events(user_id,created_at);
CREATE TABLE IF NOT EXISTS account_deletions (
 user_id TEXT PRIMARY KEY, status TEXT NOT NULL, requested_at TEXT NOT NULL, completed_at TEXT,
 provider_error TEXT
);
CREATE TABLE IF NOT EXISTS provider_credentials (
 user_id TEXT NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
 provider TEXT NOT NULL, ciphertext TEXT NOT NULL, updated_at TEXT NOT NULL,
 PRIMARY KEY(user_id,provider)
);
CREATE TABLE IF NOT EXISTS rate_limit_windows (
 key_hash TEXT PRIMARY KEY, window_start INTEGER NOT NULL, requests INTEGER NOT NULL
);
INSERT INTO schema_versions(version) VALUES ('0003') ON CONFLICT DO NOTHING;

ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON user_preferences FROM anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON user_preferences TO eatme_backend;
CREATE POLICY backend_application ON user_preferences FOR ALL TO eatme_backend USING(TRUE) WITH CHECK(TRUE);
ALTER TABLE content_ownership ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON content_ownership FROM anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON content_ownership TO eatme_backend;
CREATE POLICY backend_application ON content_ownership FOR ALL TO eatme_backend USING(TRUE) WITH CHECK(TRUE);
ALTER TABLE food_aliases ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON food_aliases FROM anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON food_aliases TO eatme_backend;
CREATE POLICY backend_application ON food_aliases FOR ALL TO eatme_backend USING(TRUE) WITH CHECK(TRUE);
ALTER TABLE food_products ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON food_products FROM anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON food_products TO eatme_backend;
CREATE POLICY backend_application ON food_products FOR ALL TO eatme_backend USING(TRUE) WITH CHECK(TRUE);
ALTER TABLE inventory_metadata ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON inventory_metadata FROM anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON inventory_metadata TO eatme_backend;
CREATE POLICY backend_application ON inventory_metadata FOR ALL TO eatme_backend USING(TRUE) WITH CHECK(TRUE);
ALTER TABLE recipe_favorites ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON recipe_favorites FROM anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON recipe_favorites TO eatme_backend;
CREATE POLICY backend_application ON recipe_favorites FOR ALL TO eatme_backend USING(TRUE) WITH CHECK(TRUE);
ALTER TABLE recipe_feedback ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON recipe_feedback FROM anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON recipe_feedback TO eatme_backend;
CREATE POLICY backend_application ON recipe_feedback FOR ALL TO eatme_backend USING(TRUE) WITH CHECK(TRUE);
ALTER TABLE household_invitations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON household_invitations FROM anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON household_invitations TO eatme_backend;
CREATE POLICY backend_application ON household_invitations FOR ALL TO eatme_backend USING(TRUE) WITH CHECK(TRUE);
ALTER TABLE household_settings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON household_settings FROM anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON household_settings TO eatme_backend;
CREATE POLICY backend_application ON household_settings FOR ALL TO eatme_backend USING(TRUE) WITH CHECK(TRUE);
ALTER TABLE member_permissions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON member_permissions FROM anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON member_permissions TO eatme_backend;
CREATE POLICY backend_application ON member_permissions FOR ALL TO eatme_backend USING(TRUE) WITH CHECK(TRUE);
ALTER TABLE shopping_items ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON shopping_items FROM anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON shopping_items TO eatme_backend;
CREATE POLICY backend_application ON shopping_items FOR ALL TO eatme_backend USING(TRUE) WITH CHECK(TRUE);
ALTER TABLE meal_plans ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON meal_plans FROM anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON meal_plans TO eatme_backend;
CREATE POLICY backend_application ON meal_plans FOR ALL TO eatme_backend USING(TRUE) WITH CHECK(TRUE);
ALTER TABLE leftover_state ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON leftover_state FROM anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON leftover_state TO eatme_backend;
CREATE POLICY backend_application ON leftover_state FOR ALL TO eatme_backend USING(TRUE) WITH CHECK(TRUE);
ALTER TABLE leftover_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON leftover_events FROM anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON leftover_events TO eatme_backend;
CREATE POLICY backend_application ON leftover_events FOR ALL TO eatme_backend USING(TRUE) WITH CHECK(TRUE);
ALTER TABLE processing_jobs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON processing_jobs FROM anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON processing_jobs TO eatme_backend;
CREATE POLICY backend_application ON processing_jobs FOR ALL TO eatme_backend USING(TRUE) WITH CHECK(TRUE);
ALTER TABLE media_objects ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON media_objects FROM anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON media_objects TO eatme_backend;
CREATE POLICY backend_application ON media_objects FOR ALL TO eatme_backend USING(TRUE) WITH CHECK(TRUE);
ALTER TABLE governed_content ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON governed_content FROM anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON governed_content TO eatme_backend;
CREATE POLICY backend_application ON governed_content FOR ALL TO eatme_backend USING(TRUE) WITH CHECK(TRUE);
ALTER TABLE admin_roles ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON admin_roles FROM anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON admin_roles TO eatme_backend;
CREATE POLICY backend_application ON admin_roles FOR ALL TO eatme_backend USING(TRUE) WITH CHECK(TRUE);
ALTER TABLE data_reports ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON data_reports FROM anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON data_reports TO eatme_backend;
CREATE POLICY backend_application ON data_reports FOR ALL TO eatme_backend USING(TRUE) WITH CHECK(TRUE);
ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON notification_preferences FROM anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON notification_preferences TO eatme_backend;
CREATE POLICY backend_application ON notification_preferences FOR ALL TO eatme_backend USING(TRUE) WITH CHECK(TRUE);
ALTER TABLE notification_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON notification_events FROM anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON notification_events TO eatme_backend;
CREATE POLICY backend_application ON notification_events FOR ALL TO eatme_backend USING(TRUE) WITH CHECK(TRUE);
ALTER TABLE feature_flags ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON feature_flags FROM anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON feature_flags TO eatme_backend;
CREATE POLICY backend_application ON feature_flags FOR ALL TO eatme_backend USING(TRUE) WITH CHECK(TRUE);
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON subscriptions FROM anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON subscriptions TO eatme_backend;
CREATE POLICY backend_application ON subscriptions FOR ALL TO eatme_backend USING(TRUE) WITH CHECK(TRUE);
ALTER TABLE provider_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON provider_events FROM anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON provider_events TO eatme_backend;
CREATE POLICY backend_application ON provider_events FOR ALL TO eatme_backend USING(TRUE) WITH CHECK(TRUE);
ALTER TABLE usage_counters ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON usage_counters FROM anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON usage_counters TO eatme_backend;
CREATE POLICY backend_application ON usage_counters FOR ALL TO eatme_backend USING(TRUE) WITH CHECK(TRUE);
ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON analytics_events FROM anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON analytics_events TO eatme_backend;
CREATE POLICY backend_application ON analytics_events FOR ALL TO eatme_backend USING(TRUE) WITH CHECK(TRUE);
ALTER TABLE account_deletions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON account_deletions FROM anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON account_deletions TO eatme_backend;
CREATE POLICY backend_application ON account_deletions FOR ALL TO eatme_backend USING(TRUE) WITH CHECK(TRUE);
ALTER TABLE provider_credentials ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON provider_credentials FROM anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON provider_credentials TO eatme_backend;
CREATE POLICY backend_application ON provider_credentials FOR ALL TO eatme_backend USING(TRUE) WITH CHECK(TRUE);
ALTER TABLE rate_limit_windows ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON rate_limit_windows FROM anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON rate_limit_windows TO eatme_backend;
CREATE POLICY backend_application ON rate_limit_windows FOR ALL TO eatme_backend USING(TRUE) WITH CHECK(TRUE);
-- Private imports and governed drafts are served only through the authorized API.
REVOKE SELECT ON recipes,foods FROM authenticated;
GRANT INSERT,UPDATE,DELETE ON foods,recipes,diet_definitions,diet_versions TO eatme_backend;
COMMIT;
