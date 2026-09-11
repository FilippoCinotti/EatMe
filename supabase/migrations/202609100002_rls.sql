BEGIN;
REVOKE CREATE ON SCHEMA public FROM anon, authenticated;

DO $$ BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='eatme_backend') THEN
  CREATE ROLE eatme_backend NOLOGIN;
 END IF;
END $$;
GRANT USAGE ON SCHEMA public TO eatme_backend;

-- Only a server database login explicitly granted this role may use backend policies.
-- The mobile app has neither a database password nor a service role key.
GRANT SELECT, INSERT, UPDATE, DELETE ON
 profiles,households,household_members,consents,inventory_batches,inventory_events,
 cooking_sessions,leftovers,recommendation_traces,operations TO eatme_backend;
GRANT SELECT ON foods,recipes,diet_definitions,diet_versions,schema_versions TO eatme_backend;
GRANT SELECT,INSERT ON audit_events TO eatme_backend;

CREATE OR REPLACE FUNCTION public.eatme_is_member(target TEXT) RETURNS BOOLEAN
LANGUAGE SQL STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT EXISTS(SELECT 1 FROM public.household_members
   WHERE household_id=target AND user_id=auth.uid()::TEXT)
$$;
REVOKE ALL ON FUNCTION public.eatme_is_member(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.eatme_is_member(TEXT) TO authenticated;

DO $$ DECLARE relation TEXT; BEGIN
 FOREACH relation IN ARRAY ARRAY['profiles','households','household_members','consents',
  'diet_definitions','diet_versions','foods','recipes','inventory_batches','inventory_events',
  'cooking_sessions','leftovers','recommendation_traces','operations','audit_events',
  'dev_accounts','dev_sessions','schema_versions'] LOOP
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',relation);
  EXECUTE format('REVOKE ALL ON public.%I FROM anon, authenticated',relation);
 END LOOP;
END $$;

DO $$ DECLARE relation TEXT; BEGIN
 FOREACH relation IN ARRAY ARRAY['profiles','households','household_members','consents',
  'diet_definitions','diet_versions','foods','recipes','inventory_batches','inventory_events',
  'cooking_sessions','leftovers','recommendation_traces','operations','audit_events','schema_versions'] LOOP
  EXECUTE format('CREATE POLICY backend_application ON public.%I FOR ALL TO eatme_backend USING(TRUE) WITH CHECK(TRUE)',relation);
 END LOOP;
END $$;

GRANT SELECT ON profiles,households,household_members,consents,inventory_batches,
 inventory_events,cooking_sessions,leftovers,recommendation_traces TO authenticated;
GRANT SELECT ON foods,recipes,diet_definitions,diet_versions TO authenticated;

CREATE POLICY profile_self ON profiles FOR SELECT TO authenticated USING(user_id=auth.uid()::TEXT);
CREATE POLICY consent_self ON consents FOR SELECT TO authenticated USING(user_id=auth.uid()::TEXT);
CREATE POLICY household_read ON households FOR SELECT TO authenticated USING(public.eatme_is_member(id));
CREATE POLICY members_read ON household_members FOR SELECT TO authenticated USING(public.eatme_is_member(household_id));
CREATE POLICY inventory_read ON inventory_batches FOR SELECT TO authenticated USING(public.eatme_is_member(household_id));
CREATE POLICY events_read ON inventory_events FOR SELECT TO authenticated USING(public.eatme_is_member(household_id));
CREATE POLICY leftovers_read ON leftovers FOR SELECT TO authenticated USING(public.eatme_is_member(household_id));
CREATE POLICY cooking_self ON cooking_sessions FOR SELECT TO authenticated USING(user_id=auth.uid()::TEXT);
CREATE POLICY recommendation_self ON recommendation_traces FOR SELECT TO authenticated USING(user_id=auth.uid()::TEXT);
CREATE POLICY foods_read ON foods FOR SELECT TO authenticated USING(TRUE);
CREATE POLICY recipes_read ON recipes FOR SELECT TO authenticated USING(TRUE);
CREATE POLICY published_diet_read ON diet_definitions FOR SELECT TO authenticated USING(data::JSONB->>'status'='PUBLISHED');
CREATE POLICY published_rules_read ON diet_versions FOR SELECT TO authenticated USING(status='PUBLISHED');

-- No client write policies: mutations must pass through the application service.
-- No public policies for operations, audit_events or development credentials.
INSERT INTO schema_versions(version) VALUES ('0002') ON CONFLICT DO NOTHING;
COMMIT;
