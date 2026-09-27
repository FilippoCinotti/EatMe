BEGIN;

-- Household pantry staples: food ids assumed always available (salt-like
-- basics). Written only by the API; no anon/authenticated access.
CREATE TABLE IF NOT EXISTS public.household_pantry (
 household_id TEXT PRIMARY KEY REFERENCES public.households(id) ON DELETE CASCADE,
 data TEXT NOT NULL, version INTEGER NOT NULL, updated_at TEXT NOT NULL
);
ALTER TABLE public.household_pantry ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.household_pantry FROM anon, authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.household_pantry TO eatme_backend;
CREATE POLICY backend_application ON public.household_pantry FOR ALL TO eatme_backend USING(TRUE) WITH CHECK(TRUE);

INSERT INTO public.schema_versions(version) VALUES ('0007') ON CONFLICT DO NOTHING;
COMMIT;
