-- Only for an ephemeral vanilla PostgreSQL CI instance, never for Supabase.
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
-- Mirror the Supabase-managed role referenced by production grants/revokes so
-- migrations are exercised faithfully on the vanilla PostgreSQL CI service.
CREATE ROLE service_role NOLOGIN;
CREATE SCHEMA auth;
CREATE FUNCTION auth.uid() RETURNS UUID LANGUAGE SQL STABLE AS $$
 SELECT NULLIF(current_setting('request.jwt.claim.sub',true),'')::UUID
$$;
GRANT USAGE ON SCHEMA auth TO authenticated;
GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated;
