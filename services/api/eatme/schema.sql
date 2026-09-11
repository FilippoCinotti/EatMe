CREATE TABLE IF NOT EXISTS schema_versions (version TEXT PRIMARY KEY);
INSERT INTO schema_versions(version) VALUES ('0001') ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS profiles (
 user_id TEXT PRIMARY KEY, name TEXT NOT NULL, household_id TEXT NOT NULL,
 settings TEXT NOT NULL, version INTEGER NOT NULL DEFAULT 1, created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS households (
 id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, size INTEGER NOT NULL CHECK(size BETWEEN 1 AND 20),
 created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS household_members (
 household_id TEXT NOT NULL REFERENCES households(id) ON DELETE CASCADE,
 user_id TEXT NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
 role TEXT NOT NULL CHECK(role IN ('owner','member','viewer')),
 PRIMARY KEY(household_id,user_id)
);
CREATE TABLE IF NOT EXISTS consents (
 id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
 kind TEXT NOT NULL, version TEXT NOT NULL, accepted_at TEXT NOT NULL, withdrawn_at TEXT
);
CREATE TABLE IF NOT EXISTS diet_definitions (
 id TEXT PRIMARY KEY, slug TEXT NOT NULL UNIQUE, data TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS diet_versions (
 id TEXT PRIMARY KEY, diet_id TEXT NOT NULL REFERENCES diet_definitions(id),
 version INTEGER NOT NULL CHECK(version > 0), status TEXT NOT NULL,
 effective_from TEXT NOT NULL, effective_until TEXT, rules TEXT NOT NULL,
 UNIQUE(diet_id,version)
);
CREATE TABLE IF NOT EXISTS foods (id TEXT PRIMARY KEY, data TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS recipes (id TEXT PRIMARY KEY, data TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS inventory_batches (
 id TEXT PRIMARY KEY, household_id TEXT NOT NULL REFERENCES households(id) ON DELETE CASCADE,
 food_id TEXT NOT NULL REFERENCES foods(id), quantity_milli BIGINT NOT NULL CHECK(quantity_milli >= 0),
 location TEXT NOT NULL CHECK(location IN ('fridge','freezer','pantry')),
 expiry_date TEXT, expiry_kind TEXT NOT NULL CHECK(expiry_kind IN ('unknown','use_by','best_before','estimated')),
 opened_at TEXT, provenance TEXT NOT NULL, version INTEGER NOT NULL DEFAULT 1,
 created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS inventory_household_expiry ON inventory_batches(household_id,expiry_date);
CREATE TABLE IF NOT EXISTS inventory_events (
 id TEXT PRIMARY KEY, household_id TEXT NOT NULL REFERENCES households(id) ON DELETE CASCADE,
 batch_id TEXT NOT NULL, actor_id TEXT, kind TEXT NOT NULL, delta_milli BIGINT NOT NULL,
 created_at TEXT NOT NULL, metadata TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS cooking_sessions (
 id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
 household_id TEXT NOT NULL REFERENCES households(id) ON DELETE CASCADE,
 recipe_id TEXT NOT NULL REFERENCES recipes(id), data TEXT NOT NULL, created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS leftovers (
 id TEXT PRIMARY KEY, household_id TEXT NOT NULL REFERENCES households(id) ON DELETE CASCADE,
 cooking_id TEXT NOT NULL REFERENCES cooking_sessions(id) ON DELETE CASCADE,
 servings INTEGER NOT NULL CHECK(servings > 0), prepared_at TEXT NOT NULL,
 location TEXT NOT NULL, user_use_date TEXT, provenance TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS recommendation_traces (
 id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
 household_id TEXT NOT NULL REFERENCES households(id) ON DELETE CASCADE,
 data TEXT NOT NULL, created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS operations (
 user_id TEXT NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
 operation_key TEXT NOT NULL, request_hash TEXT NOT NULL, response TEXT NOT NULL,
 created_at TEXT NOT NULL, PRIMARY KEY(user_id,operation_key)
);
CREATE TABLE IF NOT EXISTS audit_events (
 id TEXT PRIMARY KEY, actor_id TEXT NOT NULL, action TEXT NOT NULL,
 subject_id TEXT NOT NULL, created_at TEXT NOT NULL, data TEXT NOT NULL
);

-- Local credential tables are disabled and ungranted in production.
CREATE TABLE IF NOT EXISTS dev_accounts (
 user_id TEXT PRIMARY KEY, email TEXT NOT NULL UNIQUE, password_hash TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS dev_sessions (
 token_hash TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES dev_accounts(user_id) ON DELETE CASCADE,
 expires_at TEXT NOT NULL
);
