BEGIN;

-- Keep the membership helper out of the exposed Data API schema. It must be
-- SECURITY DEFINER to avoid recursive household_members RLS evaluation, but
-- it is callable only by authenticated requests and always binds auth.uid().
CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon;
GRANT USAGE ON SCHEMA private TO authenticated;

CREATE OR REPLACE FUNCTION private.eatme_is_member(target TEXT) RETURNS BOOLEAN
LANGUAGE SQL STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT (SELECT auth.uid()) IS NOT NULL AND EXISTS(
  SELECT 1 FROM public.household_members
  WHERE household_id=target AND user_id=(SELECT auth.uid())::TEXT
 )
$$;
REVOKE ALL ON FUNCTION private.eatme_is_member(TEXT) FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION private.eatme_is_member(TEXT) TO authenticated;

DROP POLICY IF EXISTS household_read ON public.households;
CREATE POLICY household_read ON public.households FOR SELECT TO authenticated
 USING(private.eatme_is_member(id));
DROP POLICY IF EXISTS members_read ON public.household_members;
CREATE POLICY members_read ON public.household_members FOR SELECT TO authenticated
 USING(private.eatme_is_member(household_id));
DROP POLICY IF EXISTS inventory_read ON public.inventory_batches;
CREATE POLICY inventory_read ON public.inventory_batches FOR SELECT TO authenticated
 USING(private.eatme_is_member(household_id));
DROP POLICY IF EXISTS events_read ON public.inventory_events;
CREATE POLICY events_read ON public.inventory_events FOR SELECT TO authenticated
 USING(private.eatme_is_member(household_id));
DROP POLICY IF EXISTS leftovers_read ON public.leftovers;
CREATE POLICY leftovers_read ON public.leftovers FOR SELECT TO authenticated
 USING(private.eatme_is_member(household_id));

DROP POLICY IF EXISTS profile_self ON public.profiles;
CREATE POLICY profile_self ON public.profiles FOR SELECT TO authenticated
 USING(user_id=(SELECT auth.uid())::TEXT);
DROP POLICY IF EXISTS consent_self ON public.consents;
CREATE POLICY consent_self ON public.consents FOR SELECT TO authenticated
 USING(user_id=(SELECT auth.uid())::TEXT);
DROP POLICY IF EXISTS cooking_self ON public.cooking_sessions;
CREATE POLICY cooking_self ON public.cooking_sessions FOR SELECT TO authenticated
 USING(user_id=(SELECT auth.uid())::TEXT);
DROP POLICY IF EXISTS recommendation_self ON public.recommendation_traces;
CREATE POLICY recommendation_self ON public.recommendation_traces FOR SELECT TO authenticated
 USING(user_id=(SELECT auth.uid())::TEXT);

DROP FUNCTION IF EXISTS public.eatme_is_member(TEXT);

-- Cover Dinner foreign keys used by cascades, retention and household views.
CREATE INDEX IF NOT EXISTS dinners_household ON public.dinners(household_id);
CREATE INDEX IF NOT EXISTS dinner_saved_guests_household ON public.dinner_saved_guests(household_id);
CREATE INDEX IF NOT EXISTS dinner_participants_user ON public.dinner_participants(user_id);
CREATE INDEX IF NOT EXISTS dinner_participants_saved_guest ON public.dinner_participants(saved_guest_id);
CREATE INDEX IF NOT EXISTS dinner_invitations_dinner ON public.dinner_invitations(dinner_id);
CREATE INDEX IF NOT EXISTS dinner_guest_responses_saved_guest ON public.dinner_guest_responses(remembered_guest_id);
CREATE INDEX IF NOT EXISTS dinner_memories_household ON public.dinner_memories(household_id);

INSERT INTO public.schema_versions(version) VALUES ('0006') ON CONFLICT DO NOTHING;
COMMIT;
