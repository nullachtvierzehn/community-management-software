BEGIN;

GRANT CONNECT ON DATABASE :DATABASE_NAME TO :DATABASE_OWNER;
GRANT CONNECT ON DATABASE :DATABASE_NAME TO :DATABASE_AUTHENTICATOR;
GRANT ALL ON DATABASE :DATABASE_NAME TO :DATABASE_OWNER;
ALTER SCHEMA public OWNER TO :DATABASE_OWNER;

-- Create procrastinate schema
CREATE SCHEMA IF NOT EXISTS procrastinate AUTHORIZATION :DATABASE_OWNER;

-- Some extensions require superuser privileges, so we create them before migration time.
CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;

-- Add an immutable version of array_to_text, see https://dba.stackexchange.com/questions/299039/optimize-query-matching-first-n-items-of-an-array
CREATE OR REPLACE FUNCTION public.text_array_to_string(text[], text)
RETURNS text
LANGUAGE internal IMMUTABLE PARALLEL SAFE STRICT AS 'array_to_text';

COMMIT;
