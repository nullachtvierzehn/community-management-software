--
-- PostgreSQL database dump
--

-- Dumped from database version 16.1
-- Dumped by pg_dump version 16.1

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: app_hidden; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA app_hidden;


--
-- Name: app_private; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA app_private;


--
-- Name: app_public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA app_public;


--
-- Name: postgraphile_watch; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA postgraphile_watch;


--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

-- *not* creating schema, since initdb creates it


--
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: notification_setting; Type: TYPE; Schema: app_public; Owner: -
--

CREATE TYPE app_public.notification_setting AS ENUM (
    'silenced',
    'default',
    'deferred',
    'immediate'
);


--
-- Name: room_history_visibility; Type: TYPE; Schema: app_public; Owner: -
--

CREATE TYPE app_public.room_history_visibility AS ENUM (
    'subscription',
    'invitation',
    'specified_date',
    'always'
);


--
-- Name: room_item_type; Type: TYPE; Schema: app_public; Owner: -
--

CREATE TYPE app_public.room_item_type AS ENUM (
    'MESSAGE',
    'TOPIC'
);


--
-- Name: room_role; Type: TYPE; Schema: app_public; Owner: -
--

CREATE TYPE app_public.room_role AS ENUM (
    'banned',
    'public',
    'prospect',
    'member',
    'moderator',
    'admin'
);


--
-- Name: room_visibility; Type: TYPE; Schema: app_public; Owner: -
--

CREATE TYPE app_public.room_visibility AS ENUM (
    'subscribers',
    'organization_members',
    'signed_in_users',
    'public'
);


--
-- Name: textsearchable_entity; Type: TYPE; Schema: app_public; Owner: -
--

CREATE TYPE app_public.textsearchable_entity AS ENUM (
    'user',
    'topic'
);


--
-- Name: textsearch_match; Type: TYPE; Schema: app_public; Owner: -
--

CREATE TYPE app_public.textsearch_match AS (
	id uuid,
	type app_public.textsearchable_entity,
	title text,
	snippet text,
	rank_or_similarity real,
	user_id uuid,
	topic_id uuid
);


--
-- Name: TYPE textsearch_match; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON TYPE app_public.textsearch_match IS '
@primaryKey id
@foreignKey (user_id) references app_public.users (id)|@fieldName user
@foreignKey (topic_id) references app_public.topics (id)|@fieldName topic
';


--
-- Name: COLUMN textsearch_match.type; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.textsearch_match.type IS '@notNull
@behavior +filterBy';


--
-- Name: COLUMN textsearch_match.title; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.textsearch_match.title IS '@notNull
@behavior +orderBy +filterBy';


--
-- Name: COLUMN textsearch_match.rank_or_similarity; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.textsearch_match.rank_or_similarity IS '@notNull
@behavior +orderBy +filterBy';


--
-- Name: topic_visibility; Type: TYPE; Schema: app_public; Owner: -
--

CREATE TYPE app_public.topic_visibility AS ENUM (
    'organization_members',
    'signed_in_users',
    'public'
);


--
-- Name: tiptap_document_as_plain_text(jsonb); Type: FUNCTION; Schema: app_hidden; Owner: -
--

CREATE FUNCTION app_hidden.tiptap_document_as_plain_text(document jsonb) RETURNS text
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    AS $_$
  select string_agg(elem#>>'{}', E'\n')
  from jsonb_path_query(
    document,
    'strict $.** ? (@.type == "text" && @.text.type() == "string").text'
  ) as elem
$_$;


--
-- Name: verify_role_updates_on_room_subscriptions(); Type: FUNCTION; Schema: app_hidden; Owner: -
--

CREATE FUNCTION app_hidden.verify_role_updates_on_room_subscriptions() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  me app_public.users := app_public.current_user();
  room app_public.rooms := (select r from app_public.rooms as r where id = new.room_id);
  my_subscription app_public.room_subscriptions := (select s from app_public.my_room_subscription(room) as s);
begin
  if (new.role > old.role and me.is_admin is distinct from true) then
    if new.subscriber_id = me.id then
      raise exception 'cannot upgrade your own privileges';
    elsif my_subscription is null or new.role > my_subscription.role then
      raise exception 'cannot upgrade other subscribers to a role greater than yours';
    end if;
  end if;
  return new;
end
$$;


--
-- Name: assert_valid_password(text); Type: FUNCTION; Schema: app_private; Owner: -
--

CREATE FUNCTION app_private.assert_valid_password(new_password text) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
  -- TODO: add better assertions!
  if length(new_password) < 8 then
    raise exception 'Password is too weak' using errcode = 'WEAKP';
  end if;
end;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: users; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    username public.citext NOT NULL,
    name text,
    avatar_url text,
    is_admin boolean DEFAULT false NOT NULL,
    is_verified boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    default_handling_of_notifications app_public.notification_setting DEFAULT 'default'::app_public.notification_setting NOT NULL,
    sending_time_for_deferred_notifications time without time zone DEFAULT '20:00:00'::time without time zone NOT NULL,
    CONSTRAINT users_avatar_url_check CHECK ((avatar_url ~ '^https?://[^/]+'::text)),
    CONSTRAINT users_username_check CHECK (((length((username)::text) >= 2) AND (length((username)::text) <= 24) AND (username OPERATOR(public.~) '^[a-zA-Z]([_]?[a-zA-Z0-9])+$'::public.citext)))
);


--
-- Name: TABLE users; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON TABLE app_public.users IS 'A user who can log in to the application.';


--
-- Name: COLUMN users.id; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.users.id IS 'Unique identifier for the user.';


--
-- Name: COLUMN users.username; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.users.username IS 'Public-facing username (or ''handle'') of the user.';


--
-- Name: COLUMN users.name; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.users.name IS 'Public-facing name (or pseudonym) of the user.';


--
-- Name: COLUMN users.avatar_url; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.users.avatar_url IS 'Optional avatar URL.';


--
-- Name: COLUMN users.is_admin; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.users.is_admin IS 'If true, the user has elevated privileges.';


--
-- Name: COLUMN users.default_handling_of_notifications; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.users.default_handling_of_notifications IS 'Users can be notified about activities in the rooms they have subscribed to. This is the default setting. You can change it for each room.';


--
-- Name: COLUMN users.sending_time_for_deferred_notifications; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.users.sending_time_for_deferred_notifications IS 'If there are any delayed notifications, they are sent at this time every day.';


--
-- Name: link_or_register_user(uuid, character varying, character varying, json, json); Type: FUNCTION; Schema: app_private; Owner: -
--

CREATE FUNCTION app_private.link_or_register_user(f_user_id uuid, f_service character varying, f_identifier character varying, f_profile json, f_auth_details json) RETURNS app_public.users
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
declare
  v_matched_user_id uuid;
  v_matched_authentication_id uuid;
  v_email citext;
  v_name text;
  v_avatar_url text;
  v_user app_public.users;
  v_user_email app_public.user_emails;
begin
  -- See if a user account already matches these details
  select id, user_id
    into v_matched_authentication_id, v_matched_user_id
    from app_public.user_authentications
    where service = f_service
    and identifier = f_identifier
    limit 1;

  if v_matched_user_id is not null and f_user_id is not null and v_matched_user_id <> f_user_id then
    raise exception 'A different user already has this account linked.' using errcode = 'TAKEN';
  end if;

  v_email = f_profile ->> 'email';
  v_name := f_profile ->> 'name';
  v_avatar_url := f_profile ->> 'avatar_url';

  if v_matched_authentication_id is null then
    if f_user_id is not null then
      -- Link new account to logged in user account
      insert into app_public.user_authentications (user_id, service, identifier, details) values
        (f_user_id, f_service, f_identifier, f_profile) returning id, user_id into v_matched_authentication_id, v_matched_user_id;
      insert into app_private.user_authentication_secrets (user_authentication_id, details) values
        (v_matched_authentication_id, f_auth_details);
      perform graphile_worker.add_job(
        'user__audit',
        json_build_object(
          'type', 'linked_account',
          'user_id', f_user_id,
          'extra1', f_service,
          'extra2', f_identifier,
          'current_user_id', app_public.current_user_id()
        ));
    elsif v_email is not null then
      -- See if the email is registered
      select * into v_user_email from app_public.user_emails where email = v_email and is_verified is true;
      if v_user_email is not null then
        -- User exists!
        insert into app_public.user_authentications (user_id, service, identifier, details) values
          (v_user_email.user_id, f_service, f_identifier, f_profile) returning id, user_id into v_matched_authentication_id, v_matched_user_id;
        insert into app_private.user_authentication_secrets (user_authentication_id, details) values
          (v_matched_authentication_id, f_auth_details);
        perform graphile_worker.add_job(
          'user__audit',
          json_build_object(
            'type', 'linked_account',
            'user_id', f_user_id,
            'extra1', f_service,
            'extra2', f_identifier,
            'current_user_id', app_public.current_user_id()
          ));
      end if;
    end if;
  end if;
  if v_matched_user_id is null and f_user_id is null and v_matched_authentication_id is null then
    -- Create and return a new user account
    return app_private.register_user(f_service, f_identifier, f_profile, f_auth_details, true);
  else
    if v_matched_authentication_id is not null then
      update app_public.user_authentications
        set details = f_profile
        where id = v_matched_authentication_id;
      update app_private.user_authentication_secrets
        set details = f_auth_details
        where user_authentication_id = v_matched_authentication_id;
      update app_public.users
        set
          name = coalesce(users.name, v_name),
          avatar_url = coalesce(users.avatar_url, v_avatar_url)
        where id = v_matched_user_id
        returning  * into v_user;
      return v_user;
    else
      -- v_matched_authentication_id is null
      -- -> v_matched_user_id is null (they're paired)
      -- -> f_user_id is not null (because the if clause above)
      -- -> v_matched_authentication_id is not null (because of the separate if block above creating a user_authentications)
      -- -> contradiction.
      raise exception 'This should not occur';
    end if;
  end if;
end;
$$;


--
-- Name: FUNCTION link_or_register_user(f_user_id uuid, f_service character varying, f_identifier character varying, f_profile json, f_auth_details json); Type: COMMENT; Schema: app_private; Owner: -
--

COMMENT ON FUNCTION app_private.link_or_register_user(f_user_id uuid, f_service character varying, f_identifier character varying, f_profile json, f_auth_details json) IS 'If you''re logged in, this will link an additional OAuth login to your account if necessary. If you''re logged out it may find if an account already exists (based on OAuth details or email address) and return that, or create a new user account if necessary.';


--
-- Name: sessions; Type: TABLE; Schema: app_private; Owner: -
--

CREATE TABLE app_private.sessions (
    uuid uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    last_active timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: login(public.citext, text); Type: FUNCTION; Schema: app_private; Owner: -
--

CREATE FUNCTION app_private.login(username public.citext, password text) RETURNS app_private.sessions
    LANGUAGE plpgsql STRICT
    AS $$
declare
  v_user app_public.users;
  v_user_secret app_private.user_secrets;
  v_login_attempt_window_duration interval = interval '5 minutes';
  v_session app_private.sessions;
begin
  if username like '%@%' then
    -- It's an email
    select users.* into v_user
    from app_public.users
    inner join app_public.user_emails
    on (user_emails.user_id = users.id)
    where user_emails.email = login.username
    order by
      user_emails.is_verified desc, -- Prefer verified email
      user_emails.created_at asc -- Failing that, prefer the first registered (unverified users _should_ verify before logging in)
    limit 1;
  else
    -- It's a username
    select users.* into v_user
    from app_public.users
    where users.username = login.username;
  end if;

  if not (v_user is null) then
    -- Load their secrets
    select * into v_user_secret from app_private.user_secrets
    where user_secrets.user_id = v_user.id;

    -- Have there been too many login attempts?
    if (
      v_user_secret.first_failed_password_attempt is not null
    and
      v_user_secret.first_failed_password_attempt > NOW() - v_login_attempt_window_duration
    and
      v_user_secret.failed_password_attempts >= 3
    ) then
      raise exception 'User account locked - too many login attempts. Try again after 5 minutes.' using errcode = 'LOCKD';
    end if;

    -- Not too many login attempts, let's check the password.
    -- NOTE: `password_hash` could be null, this is fine since `NULL = NULL` is null, and null is falsy.
    if v_user_secret.password_hash = crypt(password, v_user_secret.password_hash) then
      -- Excellent - they're logged in! Let's reset the attempt tracking
      update app_private.user_secrets
      set failed_password_attempts = 0, first_failed_password_attempt = null, last_login_at = now()
      where user_id = v_user.id;
      -- Create a session for the user
      insert into app_private.sessions (user_id) values (v_user.id) returning * into v_session;
      -- And finally return the session
      return v_session;
    else
      -- Wrong password, bump all the attempt tracking figures
      update app_private.user_secrets
      set
        failed_password_attempts = (case when first_failed_password_attempt is null or first_failed_password_attempt < now() - v_login_attempt_window_duration then 1 else failed_password_attempts + 1 end),
        first_failed_password_attempt = (case when first_failed_password_attempt is null or first_failed_password_attempt < now() - v_login_attempt_window_duration then now() else first_failed_password_attempt end)
      where user_id = v_user.id;
      return null; -- Must not throw otherwise transaction will be aborted and attempts won't be recorded
    end if;
  else
    -- No user with that email/username was found
    return null;
  end if;
end;
$$;


--
-- Name: FUNCTION login(username public.citext, password text); Type: COMMENT; Schema: app_private; Owner: -
--

COMMENT ON FUNCTION app_private.login(username public.citext, password text) IS 'Returns a user that matches the username/password combo, or null on failure.';


--
-- Name: really_create_user(public.citext, text, boolean, text, text, text); Type: FUNCTION; Schema: app_private; Owner: -
--

CREATE FUNCTION app_private.really_create_user(username public.citext, email text, email_is_verified boolean, name text, avatar_url text, password text DEFAULT NULL::text) RETURNS app_public.users
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
declare
  v_user app_public.users;
  v_username citext = username;
begin
  if password is not null then
    perform app_private.assert_valid_password(password);
  end if;
  if email is null then
    raise exception 'Email is required' using errcode = 'MODAT';
  end if;

  -- Insert the new user
  insert into app_public.users (username, name, avatar_url) values
    (v_username, name, avatar_url)
    returning * into v_user;

	-- Add the user's email
  insert into app_public.user_emails (user_id, email, is_verified, is_primary)
  values (v_user.id, email, email_is_verified, email_is_verified);

  -- Store the password
  if password is not null then
    update app_private.user_secrets
    set password_hash = crypt(password, gen_salt('bf'))
    where user_id = v_user.id;
  end if;

  -- Refresh the user
  select * into v_user from app_public.users where id = v_user.id;

  return v_user;
end;
$$;


--
-- Name: FUNCTION really_create_user(username public.citext, email text, email_is_verified boolean, name text, avatar_url text, password text); Type: COMMENT; Schema: app_private; Owner: -
--

COMMENT ON FUNCTION app_private.really_create_user(username public.citext, email text, email_is_verified boolean, name text, avatar_url text, password text) IS 'Creates a user account. All arguments are optional, it trusts the calling method to perform sanitisation.';


--
-- Name: register_user(character varying, character varying, json, json, boolean); Type: FUNCTION; Schema: app_private; Owner: -
--

CREATE FUNCTION app_private.register_user(f_service character varying, f_identifier character varying, f_profile json, f_auth_details json, f_email_is_verified boolean DEFAULT false) RETURNS app_public.users
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
declare
  v_user app_public.users;
  v_email citext;
  v_name text;
  v_username citext;
  v_avatar_url text;
  v_user_authentication_id uuid;
begin
  -- Extract data from the user’s OAuth profile data.
  v_email := f_profile ->> 'email';
  v_name := f_profile ->> 'name';
  v_username := f_profile ->> 'username';
  v_avatar_url := f_profile ->> 'avatar_url';

  -- Sanitise the username, and make it unique if necessary.
  if v_username is null then
    v_username = coalesce(v_name, 'user');
  end if;
  v_username = regexp_replace(v_username, '^[^a-z]+', '', 'gi');
  v_username = regexp_replace(v_username, '[^a-z0-9]+', '_', 'gi');
  if v_username is null or length(v_username) < 3 then
    v_username = 'user';
  end if;
  select (
    case
    when i = 0 then v_username
    else v_username || i::text
    end
  ) into v_username from generate_series(0, 1000) i
  where not exists(
    select 1
    from app_public.users
    where users.username = (
      case
      when i = 0 then v_username
      else v_username || i::text
      end
    )
  )
  limit 1;

  -- Create the user account
  v_user = app_private.really_create_user(
    username => v_username,
    email => v_email,
    email_is_verified => f_email_is_verified,
    name => v_name,
    avatar_url => v_avatar_url
  );

  -- Insert the user’s private account data (e.g. OAuth tokens)
  insert into app_public.user_authentications (user_id, service, identifier, details) values
    (v_user.id, f_service, f_identifier, f_profile) returning id into v_user_authentication_id;
  insert into app_private.user_authentication_secrets (user_authentication_id, details) values
    (v_user_authentication_id, f_auth_details);

  return v_user;
end;
$$;


--
-- Name: FUNCTION register_user(f_service character varying, f_identifier character varying, f_profile json, f_auth_details json, f_email_is_verified boolean); Type: COMMENT; Schema: app_private; Owner: -
--

COMMENT ON FUNCTION app_private.register_user(f_service character varying, f_identifier character varying, f_profile json, f_auth_details json, f_email_is_verified boolean) IS 'Used to register a user from information gleaned from OAuth. Primarily used by link_or_register_user';


--
-- Name: reset_password(uuid, text, text); Type: FUNCTION; Schema: app_private; Owner: -
--

CREATE FUNCTION app_private.reset_password(user_id uuid, reset_token text, new_password text) RETURNS boolean
    LANGUAGE plpgsql STRICT
    AS $$
declare
  v_user app_public.users;
  v_user_secret app_private.user_secrets;
  v_token_max_duration interval = interval '3 days';
begin
  select users.* into v_user
  from app_public.users
  where id = user_id;

  if not (v_user is null) then
    -- Load their secrets
    select * into v_user_secret from app_private.user_secrets
    where user_secrets.user_id = v_user.id;

    -- Have there been too many reset attempts?
    if (
      v_user_secret.first_failed_reset_password_attempt is not null
    and
      v_user_secret.first_failed_reset_password_attempt > NOW() - v_token_max_duration
    and
      v_user_secret.failed_reset_password_attempts >= 20
    ) then
      raise exception 'Password reset locked - too many reset attempts' using errcode = 'LOCKD';
    end if;

    -- Not too many reset attempts, let's check the token
    if v_user_secret.reset_password_token = reset_token then
      -- Excellent - they're legit

      perform app_private.assert_valid_password(new_password);

      -- Let's reset the password as requested
      update app_private.user_secrets
      set
        password_hash = crypt(new_password, gen_salt('bf')),
        failed_password_attempts = 0,
        first_failed_password_attempt = null,
        reset_password_token = null,
        reset_password_token_generated = null,
        failed_reset_password_attempts = 0,
        first_failed_reset_password_attempt = null
      where user_secrets.user_id = v_user.id;

      -- Revoke the users' sessions
      delete from app_private.sessions
      where sessions.user_id = v_user.id;

      -- Notify user their password was reset
      perform graphile_worker.add_job(
        'user__audit',
        json_build_object(
          'type', 'reset_password',
          'user_id', v_user.id,
          'current_user_id', app_public.current_user_id()
        ));

      return true;
    else
      -- Wrong token, bump all the attempt tracking figures
      update app_private.user_secrets
      set
        failed_reset_password_attempts = (case when first_failed_reset_password_attempt is null or first_failed_reset_password_attempt < now() - v_token_max_duration then 1 else failed_reset_password_attempts + 1 end),
        first_failed_reset_password_attempt = (case when first_failed_reset_password_attempt is null or first_failed_reset_password_attempt < now() - v_token_max_duration then now() else first_failed_reset_password_attempt end)
      where user_secrets.user_id = v_user.id;
      return null;
    end if;
  else
    -- No user with that id was found
    return null;
  end if;
end;
$$;


--
-- Name: tg__add_audit_job(); Type: FUNCTION; Schema: app_private; Owner: -
--

CREATE FUNCTION app_private.tg__add_audit_job() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $_$
declare
  v_user_id uuid;
  v_type text = TG_ARGV[0];
  v_user_id_attribute text = TG_ARGV[1];
  v_extra_attribute1 text = TG_ARGV[2];
  v_extra_attribute2 text = TG_ARGV[3];
  v_extra_attribute3 text = TG_ARGV[4];
  v_extra1 text;
  v_extra2 text;
  v_extra3 text;
begin
  if v_user_id_attribute is null then
    raise exception 'Invalid tg__add_audit_job call';
  end if;

  execute 'select ($1.' || quote_ident(v_user_id_attribute) || ')::uuid'
    using (case when TG_OP = 'INSERT' then NEW else OLD end)
    into v_user_id;

  if v_extra_attribute1 is not null then
    execute 'select ($1.' || quote_ident(v_extra_attribute1) || ')::text'
      using (case when TG_OP = 'DELETE' then OLD else NEW end)
      into v_extra1;
  end if;
  if v_extra_attribute2 is not null then
    execute 'select ($1.' || quote_ident(v_extra_attribute2) || ')::text'
      using (case when TG_OP = 'DELETE' then OLD else NEW end)
      into v_extra2;
  end if;
  if v_extra_attribute3 is not null then
    execute 'select ($1.' || quote_ident(v_extra_attribute3) || ')::text'
      using (case when TG_OP = 'DELETE' then OLD else NEW end)
      into v_extra3;
  end if;

  if v_user_id is not null then
    perform graphile_worker.add_job(
      'user__audit',
      json_build_object(
        'type', v_type,
        'user_id', v_user_id,
        'extra1', v_extra1,
        'extra2', v_extra2,
        'extra3', v_extra3,
        'current_user_id', app_public.current_user_id(),
        'schema', TG_TABLE_SCHEMA,
        'table', TG_TABLE_NAME
      ));
  end if;

  return NEW;
end;
$_$;


--
-- Name: FUNCTION tg__add_audit_job(); Type: COMMENT; Schema: app_private; Owner: -
--

COMMENT ON FUNCTION app_private.tg__add_audit_job() IS 'For notifying a user that an auditable action has taken place. Call with audit event name, user ID attribute name, and optionally another value to be included (e.g. the PK of the table, or some other relevant information). e.g. `tg__add_audit_job(''added_email'', ''user_id'', ''email'')`';


--
-- Name: tg__add_job(); Type: FUNCTION; Schema: app_private; Owner: -
--

CREATE FUNCTION app_private.tg__add_job() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
begin
  perform graphile_worker.add_job(tg_argv[0], json_build_object('id', NEW.id));
  return NEW;
end;
$$;


--
-- Name: FUNCTION tg__add_job(); Type: COMMENT; Schema: app_private; Owner: -
--

COMMENT ON FUNCTION app_private.tg__add_job() IS 'Useful shortcut to create a job on insert/update. Pass the task name as the first trigger argument, and optionally the queue name as the second argument. The record id will automatically be available on the JSON payload.';


--
-- Name: tg__timestamps(); Type: FUNCTION; Schema: app_private; Owner: -
--

CREATE FUNCTION app_private.tg__timestamps() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
begin
  NEW.created_at = (case when TG_OP = 'INSERT' then NOW() else OLD.created_at end);
  NEW.updated_at = (case when TG_OP = 'UPDATE' and OLD.updated_at >= NOW() then OLD.updated_at + interval '1 millisecond' else NOW() end);
  return NEW;
end;
$$;


--
-- Name: FUNCTION tg__timestamps(); Type: COMMENT; Schema: app_private; Owner: -
--

COMMENT ON FUNCTION app_private.tg__timestamps() IS 'This trigger should be called on all tables with created_at, updated_at - it ensures that they cannot be manipulated and that updated_at will always be larger than the previous updated_at.';


--
-- Name: tg_user_email_secrets__insert_with_user_email(); Type: FUNCTION; Schema: app_private; Owner: -
--

CREATE FUNCTION app_private.tg_user_email_secrets__insert_with_user_email() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
declare
  v_verification_token text;
begin
  if NEW.is_verified is false then
    v_verification_token = encode(gen_random_bytes(7), 'hex');
  end if;
  insert into app_private.user_email_secrets(user_email_id, verification_token) values(NEW.id, v_verification_token);
  return NEW;
end;
$$;


--
-- Name: FUNCTION tg_user_email_secrets__insert_with_user_email(); Type: COMMENT; Schema: app_private; Owner: -
--

COMMENT ON FUNCTION app_private.tg_user_email_secrets__insert_with_user_email() IS 'Ensures that every user_email record has an associated user_email_secret record.';


--
-- Name: tg_user_secrets__insert_with_user(); Type: FUNCTION; Schema: app_private; Owner: -
--

CREATE FUNCTION app_private.tg_user_secrets__insert_with_user() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
begin
  insert into app_private.user_secrets(user_id) values(NEW.id);
  return NEW;
end;
$$;


--
-- Name: FUNCTION tg_user_secrets__insert_with_user(); Type: COMMENT; Schema: app_private; Owner: -
--

COMMENT ON FUNCTION app_private.tg_user_secrets__insert_with_user() IS 'Ensures that every user record has an associated user_secret record.';


--
-- Name: accept_invitation_to_organization(uuid, text); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.accept_invitation_to_organization(invitation_id uuid, code text DEFAULT NULL::text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
declare
  v_organization app_public.organizations;
begin
  v_organization = app_public.organization_for_invitation(invitation_id, code);

  -- Accept the user into the organization
  insert into app_public.organization_memberships (organization_id, user_id)
    values(v_organization.id, app_public.current_user_id())
    on conflict do nothing;

  -- Delete the invitation
  delete from app_public.organization_invitations where id = invitation_id;
end;
$$;


--
-- Name: change_password(text, text); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.change_password(old_password text, new_password text) RETURNS boolean
    LANGUAGE plpgsql STRICT SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
declare
  v_user app_public.users;
  v_user_secret app_private.user_secrets;
begin
  select users.* into v_user
  from app_public.users
  where id = app_public.current_user_id();

  if not (v_user is null) then
    -- Load their secrets
    select * into v_user_secret from app_private.user_secrets
    where user_secrets.user_id = v_user.id;

    if v_user_secret.password_hash = crypt(old_password, v_user_secret.password_hash) then
      perform app_private.assert_valid_password(new_password);

      -- Reset the password as requested
      update app_private.user_secrets
      set
        password_hash = crypt(new_password, gen_salt('bf'))
      where user_secrets.user_id = v_user.id;

      -- Revoke all other sessions
      delete from app_private.sessions
      where sessions.user_id = v_user.id
      and sessions.uuid <> app_public.current_session_id();

      -- Notify user their password was changed
      perform graphile_worker.add_job(
        'user__audit',
        json_build_object(
          'type', 'change_password',
          'user_id', v_user.id,
          'current_user_id', app_public.current_user_id()
        ));

      return true;
    else
      raise exception 'Incorrect password' using errcode = 'CREDS';
    end if;
  else
    raise exception 'You must log in to change your password' using errcode = 'LOGIN';
  end if;
end;
$$;


--
-- Name: FUNCTION change_password(old_password text, new_password text); Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON FUNCTION app_public.change_password(old_password text, new_password text) IS 'Enter your old password and a new password to change your password.';


--
-- Name: confirm_account_deletion(text); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.confirm_account_deletion(token text) RETURNS boolean
    LANGUAGE plpgsql STRICT SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
declare
  v_user_secret app_private.user_secrets;
  v_token_max_duration interval = interval '3 days';
begin
  if app_public.current_user_id() is null then
    raise exception 'You must log in to delete your account' using errcode = 'LOGIN';
  end if;

  select * into v_user_secret
    from app_private.user_secrets
    where user_secrets.user_id = app_public.current_user_id();

  if v_user_secret is null then
    -- Success: they're already deleted
    return true;
  end if;

  -- Check the token
  if (
    -- token is still valid
    v_user_secret.delete_account_token_generated > now() - v_token_max_duration
  and
    -- token matches
    v_user_secret.delete_account_token = token
  ) then
    -- Token passes; delete their account :(
    delete from app_public.users where id = app_public.current_user_id();
    return true;
  end if;

  raise exception 'The supplied token was incorrect - perhaps you''re logged in to the wrong account, or the token has expired?' using errcode = 'DNIED';
end;
$$;


--
-- Name: FUNCTION confirm_account_deletion(token text); Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON FUNCTION app_public.confirm_account_deletion(token text) IS 'If you''re certain you want to delete your account, use `requestAccountDeletion` to request an account deletion token, and then supply the token through this mutation to complete account deletion.';


--
-- Name: organizations; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.organizations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    slug public.citext NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: create_organization(public.citext, text); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.create_organization(slug public.citext, name text) RETURNS app_public.organizations
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
declare
  v_org app_public.organizations;
begin
  if app_public.current_user_id() is null then
    raise exception 'You must log in to create an organization' using errcode = 'LOGIN';
  end if;
  insert into app_public.organizations (slug, name) values (slug, name) returning * into v_org;
  insert into app_public.organization_memberships (organization_id, user_id, is_owner, is_billing_contact)
    values(v_org.id, app_public.current_user_id(), true, true);
  return v_org;
end;
$$;


--
-- Name: current_session_id(); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.current_session_id() RETURNS uuid
    LANGUAGE sql STABLE
    AS $$
  select nullif(pg_catalog.current_setting('jwt.claims.session_id', true), '')::uuid;
$$;


--
-- Name: FUNCTION current_session_id(); Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON FUNCTION app_public.current_session_id() IS 'Handy method to get the current session ID.';


--
-- Name: current_user(); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public."current_user"() RETURNS app_public.users
    LANGUAGE sql STABLE
    AS $$
  select users.* from app_public.users where id = app_public.current_user_id();
$$;


--
-- Name: FUNCTION "current_user"(); Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON FUNCTION app_public."current_user"() IS 'The currently logged in user (or null if not logged in).';


--
-- Name: current_user_first_owned_organization_id(); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.current_user_first_owned_organization_id() RETURNS uuid
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
  select organization_id 
  from app_public.organization_memberships
  where 
    user_id = app_public.current_user_id() 
    and is_owner = true
  order by created_at asc
  limit 1;
$$;


--
-- Name: current_user_id(); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.current_user_id() RETURNS uuid
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
  select user_id from app_private.sessions where uuid = app_public.current_session_id();
$$;


--
-- Name: FUNCTION current_user_id(); Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON FUNCTION app_public.current_user_id() IS 'Handy method to get the current user ID for use in RLS policies, etc; in GraphQL, use `currentUser{id}` instead.';


--
-- Name: current_user_invited_organization_ids(); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.current_user_invited_organization_ids() RETURNS SETOF uuid
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
  select organization_id from app_public.organization_invitations
    where user_id = app_public.current_user_id();
$$;


--
-- Name: current_user_member_organization_ids(); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.current_user_member_organization_ids() RETURNS SETOF uuid
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
  select organization_id from app_public.organization_memberships
    where user_id = app_public.current_user_id();
$$;


--
-- Name: delete_organization(uuid); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.delete_organization(organization_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
begin
  if exists(
    select 1
    from app_public.organization_memberships
    where user_id = app_public.current_user_id()
    and organization_memberships.organization_id = delete_organization.organization_id
    and is_owner is true
  ) then
    delete from app_public.organizations where id = organization_id;
  end if;
end;
$$;


--
-- Name: room_messages; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.room_messages (
    id uuid DEFAULT public.uuid_generate_v1mc() NOT NULL,
    room_id uuid NOT NULL,
    sender_id uuid DEFAULT app_public.current_user_id(),
    answered_message_id uuid,
    body text,
    language text DEFAULT 'german'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    sent_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT supported_language CHECK ((language = ANY (ARRAY['german'::text, 'english'::text, 'french'::text])))
);


--
-- Name: fetch_draft_in_room(uuid); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.fetch_draft_in_room(room_id uuid) RETURNS app_public.room_messages
    LANGUAGE sql STABLE PARALLEL SAFE
    AS $$
  select * from app_public.room_messages
  where
    room_messages.room_id = fetch_draft_in_room.room_id
    and sent_at is null
    and sender_id = app_public.current_user_id()
$$;


--
-- Name: forgot_password(public.citext); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.forgot_password(email public.citext) RETURNS void
    LANGUAGE plpgsql STRICT SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
declare
  v_user_email app_public.user_emails;
  v_token text;
  v_token_min_duration_between_emails interval = interval '3 minutes';
  v_token_max_duration interval = interval '3 days';
  v_now timestamptz = clock_timestamp(); -- Function can be called multiple during transaction
  v_latest_attempt timestamptz;
begin
  -- Find the matching user_email:
  select user_emails.* into v_user_email
  from app_public.user_emails
  where user_emails.email = forgot_password.email
  order by is_verified desc, id desc;

  -- If there is no match:
  if v_user_email is null then
    -- This email doesn't exist in the system; trigger an email stating as much.

    -- We do not allow this email to be triggered more than once every 15
    -- minutes, so we need to track it:
    insert into app_private.unregistered_email_password_resets (email, latest_attempt)
      values (forgot_password.email, v_now)
      on conflict on constraint unregistered_email_pkey
      do update
        set latest_attempt = v_now, attempts = unregistered_email_password_resets.attempts + 1
        where unregistered_email_password_resets.latest_attempt < v_now - interval '15 minutes'
      returning latest_attempt into v_latest_attempt;

    if v_latest_attempt = v_now then
      perform graphile_worker.add_job(
        'user__forgot_password_unregistered_email',
        json_build_object('email', forgot_password.email::text)
      );
    end if;

    -- TODO: we should clear out the unregistered_email_password_resets table periodically.

    return;
  end if;

  -- There was a match.
  -- See if we've triggered a reset recently:
  if exists(
    select 1
    from app_private.user_email_secrets
    where user_email_id = v_user_email.id
    and password_reset_email_sent_at is not null
    and password_reset_email_sent_at > v_now - v_token_min_duration_between_emails
  ) then
    -- If so, take no action.
    return;
  end if;

  -- Fetch or generate reset token:
  update app_private.user_secrets
  set
    reset_password_token = (
      case
      when reset_password_token is null or reset_password_token_generated < v_now - v_token_max_duration
      then encode(gen_random_bytes(7), 'hex')
      else reset_password_token
      end
    ),
    reset_password_token_generated = (
      case
      when reset_password_token is null or reset_password_token_generated < v_now - v_token_max_duration
      then v_now
      else reset_password_token_generated
      end
    )
  where user_id = v_user_email.user_id
  returning reset_password_token into v_token;

  -- Don't allow spamming an email:
  update app_private.user_email_secrets
  set password_reset_email_sent_at = v_now
  where user_email_id = v_user_email.id;

  -- Trigger email send:
  perform graphile_worker.add_job(
    'user__forgot_password',
    json_build_object('id', v_user_email.user_id, 'email', v_user_email.email::text, 'token', v_token)
  );

end;
$$;


--
-- Name: FUNCTION forgot_password(email public.citext); Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON FUNCTION app_public.forgot_password(email public.citext) IS 'If you''ve forgotten your password, give us one of your email addresses and we''ll send you a reset token. Note this only works if you have added an email address!';


--
-- Name: fulltext(app_public.room_messages); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.fulltext(message app_public.room_messages) RETURNS tsvector
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    AS $$
  select to_tsvector(cast("message".language as regconfig), "message".body)
$$;


--
-- Name: FUNCTION fulltext(message app_public.room_messages); Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON FUNCTION app_public.fulltext(message app_public.room_messages) IS '@behavior typeField';


--
-- Name: global_search(text, app_public.textsearchable_entity[]); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.global_search(term text, entities app_public.textsearchable_entity[] DEFAULT '{user,topic}'::app_public.textsearchable_entity[]) RETURNS SETOF app_public.textsearch_match
    LANGUAGE sql STABLE ROWS 10 PARALLEL SAFE
    AS $$
  -- fetch users
  select
    id,
    'user'::app_public.textsearchable_entity as "type",
    username as title,
    null as snippet,
    word_similarity(term, username) as rank_or_similarity,
    id as "user_id",
    null::uuid as topic_id
  from app_public.users
  where
    'user' = any (entities)
    and term <% username
  -- fetch topics
  union all
  select 
    id,
    'topic'::app_public.textsearchable_entity as "type",
    coalesce(title, slug, 'Thema ' || id) as title,
    ts_headline('german', app_hidden.tiptap_document_as_plain_text(topics.content), query) as snippet,
    ts_rank_cd(array[0.3, 0.5, 0.8, 1.0], fulltext_index_column, query, 32 /* normalization to [0..1) by rank / (rank+1) */) as rank_or_similarity,
    null::uuid as "user_id",
    id as topic_id
  from 
    app_public.topics, 
    websearch_to_tsquery('german', term) as query
  where
    'topic' = any (entities)
    and query @@ fulltext_index_column
  order by rank_or_similarity desc
$$;


--
-- Name: FUNCTION global_search(term text, entities app_public.textsearchable_entity[]); Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON FUNCTION app_public.global_search(term text, entities app_public.textsearchable_entity[]) IS '
@filterable
@sortable
';


--
-- Name: invite_to_organization(uuid, public.citext, public.citext); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.invite_to_organization(organization_id uuid, username public.citext DEFAULT NULL::public.citext, email public.citext DEFAULT NULL::public.citext) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
declare
  v_code text;
  v_user app_public.users;
begin
  -- Are we allowed to add this person
  -- Are we logged in
  if app_public.current_user_id() is null then
    raise exception 'You must log in to invite a user' using errcode = 'LOGIN';
  end if;

  select * into v_user from app_public.users where users.username = invite_to_organization.username;

  -- Are we the owner of this organization
  if not exists(
    select 1 from app_public.organization_memberships
      where organization_memberships.organization_id = invite_to_organization.organization_id
      and organization_memberships.user_id = app_public.current_user_id()
      and is_owner is true
  ) then
    raise exception 'You''re not the owner of this organization' using errcode = 'DNIED';
  end if;

  if v_user.id is not null and exists(
    select 1 from app_public.organization_memberships
      where organization_memberships.organization_id = invite_to_organization.organization_id
      and organization_memberships.user_id = v_user.id
  ) then
    raise exception 'Cannot invite someone who is already a member' using errcode = 'ISMBR';
  end if;

  if email is not null then
    v_code = encode(gen_random_bytes(7), 'hex');
  end if;

  if v_user.id is not null and not v_user.is_verified then
    raise exception 'The user you attempted to invite has not verified their account' using errcode = 'VRFY2';
  end if;

  if v_user.id is null and email is null then
    raise exception 'Could not find person to invite' using errcode = 'NTFND';
  end if;

  -- Invite the user
  insert into app_public.organization_invitations(organization_id, user_id, email, code)
    values (invite_to_organization.organization_id, v_user.id, email, v_code);
end;
$$;


--
-- Name: rooms; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.rooms (
    id uuid DEFAULT public.uuid_generate_v1mc() NOT NULL,
    title text,
    abstract text,
    organization_id uuid DEFAULT app_public.current_user_first_owned_organization_id(),
    is_visible_for app_public.room_visibility DEFAULT 'public'::app_public.room_visibility NOT NULL,
    items_are_visible_for app_public.room_role DEFAULT 'public'::app_public.room_role NOT NULL,
    items_are_visible_since app_public.room_history_visibility DEFAULT 'always'::app_public.room_history_visibility NOT NULL,
    items_are_visible_since_date timestamp with time zone DEFAULT now() NOT NULL,
    extend_visibility_of_items_by interval DEFAULT '00:00:00'::interval NOT NULL,
    is_anonymous_posting_allowed boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE rooms; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON TABLE app_public.rooms IS 'A room is a place where users meet. At the same time, it is a container for messages and handed-out materials.';


--
-- Name: COLUMN rooms.title; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.rooms.title IS 'Each room has an optional title.';


--
-- Name: COLUMN rooms.abstract; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.rooms.abstract IS 'Each room has an optional abstract.';


--
-- Name: COLUMN rooms.is_visible_for; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.rooms.is_visible_for IS 'Rooms can be visible for their subscribers only (`subscribers`), to all members of the room''s organisation (`organization_members`), for all currently signed-in users (`signed_in_users`), or general in `public`.';


--
-- Name: COLUMN rooms.items_are_visible_since; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.rooms.items_are_visible_since IS 'Sometimes you want to hide items of the room from users who join later. `since_subscription` allows subscribers to see items that were added *after* their subscription. Similarly, `since_invitation` allows subscribers to see items that were added *after* they had been invited to the room. `since_specified_date` allows all subscribers to see items after `items_are_visible_since_date`. Finally, `always` means that all items are visible for the room''s audience.';


--
-- Name: latest_message(app_public.rooms); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.latest_message(room app_public.rooms) RETURNS app_public.room_messages
    LANGUAGE sql STABLE PARALLEL SAFE
    AS $$
  select *
  from app_public.room_messages
  where
    room_id = room.id
    and sent_at is not null
  order by sent_at desc
  limit 1
$$;


--
-- Name: FUNCTION latest_message(room app_public.rooms); Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON FUNCTION app_public.latest_message(room app_public.rooms) IS '@behavior typeField';


--
-- Name: logout(); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.logout() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
begin
  -- Delete the session
  delete from app_private.sessions where uuid = app_public.current_session_id();
  -- Clear the identifier from the transaction
  perform set_config('jwt.claims.session_id', '', true);
end;
$$;


--
-- Name: user_emails; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.user_emails (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid DEFAULT app_public.current_user_id() NOT NULL,
    email public.citext NOT NULL,
    is_verified boolean DEFAULT false NOT NULL,
    is_primary boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT user_emails_email_check CHECK ((email OPERATOR(public.~) '[^@]+@[^@]+\.[^@]+'::public.citext)),
    CONSTRAINT user_emails_must_be_verified_to_be_primary CHECK (((is_primary IS FALSE) OR (is_verified IS TRUE)))
);


--
-- Name: TABLE user_emails; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON TABLE app_public.user_emails IS 'Information about a user''s email address.';


--
-- Name: COLUMN user_emails.email; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.user_emails.email IS 'The users email address, in `a@b.c` format.';


--
-- Name: COLUMN user_emails.is_verified; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.user_emails.is_verified IS 'True if the user has is_verified their email address (by clicking the link in the email we sent them, or logging in with a social login provider), false otherwise.';


--
-- Name: make_email_primary(uuid); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.make_email_primary(email_id uuid) RETURNS app_public.user_emails
    LANGUAGE plpgsql STRICT SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
declare
  v_user_email app_public.user_emails;
begin
  select * into v_user_email from app_public.user_emails where id = email_id and user_id = app_public.current_user_id();
  if v_user_email is null then
    raise exception 'That''s not your email' using errcode = 'DNIED';
    return null;
  end if;
  if v_user_email.is_verified is false then
    raise exception 'You may not make an unverified email primary' using errcode = 'VRFY1';
  end if;
  update app_public.user_emails set is_primary = false where user_id = app_public.current_user_id() and is_primary is true and id <> email_id;
  update app_public.user_emails set is_primary = true where user_id = app_public.current_user_id() and is_primary is not true and id = email_id returning * into v_user_email;
  return v_user_email;
end;
$$;


--
-- Name: FUNCTION make_email_primary(email_id uuid); Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON FUNCTION app_public.make_email_primary(email_id uuid) IS 'Your primary email is where we''ll notify of account events; other emails may be used for discovery or login. Use this when you''re changing your email address.';


--
-- Name: my_first_interaction(app_public.rooms); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.my_first_interaction(room app_public.rooms) RETURNS timestamp with time zone
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
  select least (
    -- my earliest sent message
    (select min(sent_at) from app_public.room_messages where room_messages.room_id = room.id),
    -- my subscription date
    (select min(created_at) from app_public.room_subscriptions where room_subscriptions.room_id = room.id and room_subscriptions.subscriber_id = app_public.current_user_id())
  )
$$;


--
-- Name: FUNCTION my_first_interaction(room app_public.rooms); Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON FUNCTION app_public.my_first_interaction(room app_public.rooms) IS '
@behavior typeField

Date of subscription or first sent message, whatever is earlier.
';


--
-- Name: room_subscriptions; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.room_subscriptions (
    id uuid DEFAULT public.uuid_generate_v1mc() NOT NULL,
    room_id uuid NOT NULL,
    subscriber_id uuid DEFAULT app_public.current_user_id() NOT NULL,
    role app_public.room_role DEFAULT 'member'::app_public.room_role NOT NULL,
    notifications app_public.notification_setting DEFAULT 'default'::app_public.notification_setting NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE room_subscriptions; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON TABLE app_public.room_subscriptions IS 'Users can be subscribed to rooms.';


--
-- Name: COLUMN room_subscriptions.subscriber_id; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.room_subscriptions.subscriber_id IS 'The subscribing user.';


--
-- Name: COLUMN room_subscriptions.role; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.room_subscriptions.role IS 'Maintainers can manage subscriptions and delete the room.';


--
-- Name: my_room_subscription(app_public.rooms); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.my_room_subscription(in_room app_public.rooms) RETURNS app_public.room_subscriptions
    LANGUAGE sql STABLE PARALLEL SAFE
    AS $$
  select *
  from app_public.room_subscriptions
  where (room_id, subscriber_id) = (in_room.id, app_public.current_user_id())
$$;


--
-- Name: FUNCTION my_room_subscription(in_room app_public.rooms); Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON FUNCTION app_public.my_room_subscription(in_room app_public.rooms) IS '
@behavior typeField
@filterable
@name mySubscriptionId
';


--
-- Name: my_room_subscription_id(app_public.rooms); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.my_room_subscription_id(in_room app_public.rooms) RETURNS uuid
    LANGUAGE sql STABLE PARALLEL SAFE
    AS $$
  select id
  from app_public.room_subscriptions
  where (room_id, subscriber_id) = (in_room.id, app_public.current_user_id())
$$;


--
-- Name: my_room_subscriptions(app_public.room_role); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.my_room_subscriptions(minimum_role app_public.room_role DEFAULT 'member'::app_public.room_role) RETURNS SETOF app_public.room_subscriptions
    LANGUAGE sql STABLE SECURITY DEFINER PARALLEL SAFE
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
  select * from app_public.room_subscriptions where subscriber_id = app_public.current_user_id() and "role" >= minimum_role;
$$;


--
-- Name: my_subscribed_room_ids(app_public.room_role); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.my_subscribed_room_ids(minimum_role app_public.room_role DEFAULT 'member'::app_public.room_role) RETURNS SETOF uuid
    LANGUAGE sql STABLE SECURITY DEFINER PARALLEL SAFE
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
  select room_id from app_public.room_subscriptions where subscriber_id = app_public.current_user_id() and "role" >= minimum_role;
$$;


--
-- Name: n_room_subscriptions(app_public.rooms, app_public.room_role); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.n_room_subscriptions(room app_public.rooms, min_role app_public.room_role DEFAULT 'member'::app_public.room_role) RETURNS bigint
    LANGUAGE sql STABLE PARALLEL SAFE
    AS $$
  select count(*)
  from app_public.room_subscriptions
  where 
    room_id = room.id 
    and "role" >= min_role
$$;


--
-- Name: FUNCTION n_room_subscriptions(room app_public.rooms, min_role app_public.room_role); Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON FUNCTION app_public.n_room_subscriptions(room app_public.rooms, min_role app_public.room_role) IS '
@behavior typeField
@sortable
@filterable
@fieldName nSubscriptions
';


--
-- Name: organization_for_invitation(uuid, text); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.organization_for_invitation(invitation_id uuid, code text DEFAULT NULL::text) RETURNS app_public.organizations
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
declare
  v_invitation app_public.organization_invitations;
  v_organization app_public.organizations;
begin
  if app_public.current_user_id() is null then
    raise exception 'You must log in to accept an invitation' using errcode = 'LOGIN';
  end if;

  select * into v_invitation from app_public.organization_invitations where id = invitation_id;

  if v_invitation is null then
    raise exception 'We could not find that invitation' using errcode = 'NTFND';
  end if;

  if v_invitation.user_id is not null then
    if v_invitation.user_id is distinct from app_public.current_user_id() then
      raise exception 'That invitation is not for you' using errcode = 'DNIED';
    end if;
  else
    if v_invitation.code is distinct from code then
      raise exception 'Incorrect invitation code' using errcode = 'DNIED';
    end if;
  end if;

  select * into v_organization from app_public.organizations where id = v_invitation.organization_id;

  return v_organization;
end;
$$;


--
-- Name: organizations_current_user_is_billing_contact(app_public.organizations); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.organizations_current_user_is_billing_contact(org app_public.organizations) RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
  select exists(
    select 1
    from app_public.organization_memberships
    where organization_id = org.id
    and user_id = app_public.current_user_id()
    and is_billing_contact is true
  )
$$;


--
-- Name: organizations_current_user_is_owner(app_public.organizations); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.organizations_current_user_is_owner(org app_public.organizations) RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
  select exists(
    select 1
    from app_public.organization_memberships
    where organization_id = org.id
    and user_id = app_public.current_user_id()
    and is_owner is true
  )
$$;


--
-- Name: remove_from_organization(uuid, uuid); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.remove_from_organization(organization_id uuid, user_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
declare
  v_my_membership app_public.organization_memberships;
begin
  select * into v_my_membership
    from app_public.organization_memberships
    where organization_memberships.organization_id = remove_from_organization.organization_id
    and organization_memberships.user_id = app_public.current_user_id();

  if (v_my_membership is null) then
    -- I'm not a member of that organization
    return;
  elsif v_my_membership.is_owner then
    if remove_from_organization.user_id <> app_public.current_user_id() then
      -- Delete it
    else
      -- Need to transfer ownership before I can leave
      return;
    end if;
  elsif v_my_membership.user_id = user_id then
    -- Delete it
  else
    -- Not allowed to delete it
    return;
  end if;

  if v_my_membership.is_billing_contact then
    update app_public.organization_memberships
      set is_billing_contact = false
      where id = v_my_membership.id
      returning * into v_my_membership;
    update app_public.organization_memberships
      set is_billing_contact = true
      where organization_memberships.organization_id = remove_from_organization.organization_id
      and organization_memberships.is_owner;
  end if;

  delete from app_public.organization_memberships
    where organization_memberships.organization_id = remove_from_organization.organization_id
    and organization_memberships.user_id = remove_from_organization.user_id;

end;
$$;


--
-- Name: request_account_deletion(); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.request_account_deletion() RETURNS boolean
    LANGUAGE plpgsql STRICT SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
declare
  v_user_email app_public.user_emails;
  v_token text;
  v_token_max_duration interval = interval '3 days';
begin
  if app_public.current_user_id() is null then
    raise exception 'You must log in to delete your account' using errcode = 'LOGIN';
  end if;

  -- Get the email to send account deletion token to
  select * into v_user_email
    from app_public.user_emails
    where user_id = app_public.current_user_id()
    order by is_primary desc, is_verified desc, id desc
    limit 1;

  -- Fetch or generate token
  update app_private.user_secrets
  set
    delete_account_token = (
      case
      when delete_account_token is null or delete_account_token_generated < NOW() - v_token_max_duration
      then encode(gen_random_bytes(7), 'hex')
      else delete_account_token
      end
    ),
    delete_account_token_generated = (
      case
      when delete_account_token is null or delete_account_token_generated < NOW() - v_token_max_duration
      then now()
      else delete_account_token_generated
      end
    )
  where user_id = app_public.current_user_id()
  returning delete_account_token into v_token;

  -- Trigger email send
  perform graphile_worker.add_job('user__send_delete_account_email', json_build_object('email', v_user_email.email::text, 'token', v_token));
  return true;
end;
$$;


--
-- Name: FUNCTION request_account_deletion(); Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON FUNCTION app_public.request_account_deletion() IS 'Begin the account deletion flow by requesting the confirmation email';


--
-- Name: resend_email_verification_code(uuid); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.resend_email_verification_code(email_id uuid) RETURNS boolean
    LANGUAGE plpgsql STRICT SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
begin
  if exists(
    select 1
    from app_public.user_emails
    where user_emails.id = email_id
    and user_id = app_public.current_user_id()
    and is_verified is false
  ) then
    perform graphile_worker.add_job('user_emails__send_verification', json_build_object('id', email_id));
    return true;
  end if;
  return false;
end;
$$;


--
-- Name: FUNCTION resend_email_verification_code(email_id uuid); Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON FUNCTION app_public.resend_email_verification_code(email_id uuid) IS 'If you didn''t receive the verification code for this email, we can resend it. We silently cap the rate of resends on the backend, so calls to this function may not result in another email being sent if it has been called recently.';


--
-- Name: send_room_message(uuid); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.send_room_message(draft_id uuid, OUT room_message app_public.room_messages) RETURNS app_public.room_messages
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
declare
  v_message app_public.room_messages;
  v_my_id uuid;
begin
  -- check for login
  v_my_id := app_public.current_user_id();
  if v_my_id is null then
    raise exception 'You must log to submit a draft' using errcode = 'LOGIN';
  end if;

  -- fetch message
  select * into room_message from app_public.room_messages where room_messages.id = send_room_message.draft_id and room_messages.sender_id = v_my_id;
  if not found then
    raise exception 'Could not find draft' using errcode = 'NTFND';
  end if;

  -- deny request if room message has already been sent at an ealier time.
  if room_message.sent_at is not null then
    raise exception 'message has already been sent' using errcode = 'DNIED';
  end if;

  -- mark this room message as sent
  update app_public.room_messages
    set sent_at = current_timestamp
    where room_messages.id = room_message.id
    returning * into room_message;
end
$$;


--
-- Name: tg__graphql_subscription(); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.tg__graphql_subscription() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
declare
  v_process_new bool = (TG_OP = 'INSERT' OR TG_OP = 'UPDATE');
  v_process_old bool = (TG_OP = 'UPDATE' OR TG_OP = 'DELETE');
  v_event text = TG_ARGV[0];
  v_topic_template text = TG_ARGV[1];
  v_attribute text = TG_ARGV[2];
  v_record record;
  v_sub text;
  v_topic text;
  v_i int = 0;
  v_last_topic text;
begin
  for v_i in 0..1 loop
    if (v_i = 0) and v_process_new is true then
      v_record = new;
    elsif (v_i = 1) and v_process_old is true then
      v_record = old;
    else
      continue;
    end if;
     if v_attribute is not null then
      execute 'select $1.' || quote_ident(v_attribute)
        using v_record
        into v_sub;
    end if;
    if v_sub is not null then
      v_topic = replace(v_topic_template, '$1', v_sub);
    else
      v_topic = v_topic_template;
    end if;
    if v_topic is distinct from v_last_topic then
      -- This if statement prevents us from triggering the same notification twice
      v_last_topic = v_topic;
      perform pg_notify(v_topic, json_build_object(
        'event', v_event,
        'subject', v_sub,
        'id', v_record.id
      )::text);
    end if;
  end loop;
  return v_record;
end;
$_$;


--
-- Name: FUNCTION tg__graphql_subscription(); Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON FUNCTION app_public.tg__graphql_subscription() IS 'This function enables the creation of simple focussed GraphQL subscriptions using database triggers. Read more here: https://www.graphile.org/postgraphile/subscriptions/#custom-subscriptions';


--
-- Name: tg_user_emails__forbid_if_verified(); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.tg_user_emails__forbid_if_verified() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
begin
  if exists(select 1 from app_public.user_emails where email = NEW.email and is_verified is true) then
    raise exception 'An account using that email address has already been created.' using errcode='EMTKN';
  end if;
  return NEW;
end;
$$;


--
-- Name: tg_user_emails__prevent_delete_last_email(); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.tg_user_emails__prevent_delete_last_email() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
begin
  if exists (
    with remaining as (
      select user_emails.user_id
      from app_public.user_emails
      inner join deleted
      on user_emails.user_id = deleted.user_id
      -- Don't delete last verified email
      where (user_emails.is_verified is true or not exists (
        select 1
        from deleted d2
        where d2.user_id = user_emails.user_id
        and d2.is_verified is true
      ))
      order by user_emails.id asc

      /*
       * Lock this table to prevent race conditions; see:
       * https://www.cybertec-postgresql.com/en/triggers-to-enforce-constraints/
       */
      for update of user_emails
    )
    select 1
    from app_public.users
    where id in (
      select user_id from deleted
      except
      select user_id from remaining
    )
  )
  then
    raise exception 'You must have at least one (verified) email address' using errcode = 'CDLEA';
  end if;

  return null;
end;
$$;


--
-- Name: tg_user_emails__verify_account_on_verified(); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.tg_user_emails__verify_account_on_verified() RETURNS trigger
    LANGUAGE plpgsql STRICT SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
begin
  update app_public.users set is_verified = true where id = new.user_id and is_verified is false;
  return new;
end;
$$;


--
-- Name: tg_users__deletion_organization_checks_and_actions(); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.tg_users__deletion_organization_checks_and_actions() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  -- Check they're not an organization owner
  if exists(
    select 1
    from app_public.organization_memberships
    where user_id = app_public.current_user_id()
    and is_owner is true
  ) then
    raise exception 'You cannot delete your account until you are not the owner of any organizations.' using errcode = 'OWNER';
  end if;

  -- Reassign billing contact status back to the organization owner
  update app_public.organization_memberships
    set is_billing_contact = true
    where is_owner = true
    and organization_id in (
      select organization_id
      from app_public.organization_memberships my_memberships
      where my_memberships.user_id = app_public.current_user_id()
      and is_billing_contact is true
    );

  return old;
end;
$$;


--
-- Name: text_array_to_string(text[], text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.text_array_to_string(text[], text) RETURNS text
    LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE
    AS $$array_to_text$$;


--
-- Name: topics; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.topics (
    id uuid DEFAULT public.uuid_generate_v1mc() NOT NULL,
    author_id uuid DEFAULT app_public.current_user_id(),
    organization_id uuid DEFAULT app_public.current_user_first_owned_organization_id(),
    slug text NOT NULL,
    title text,
    license text,
    tags text[] DEFAULT '{}'::text[] NOT NULL,
    is_visible_for app_public.topic_visibility DEFAULT 'public'::app_public.topic_visibility NOT NULL,
    content jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    fulltext_index_column tsvector GENERATED ALWAYS AS ((((setweight(to_tsvector('german'::regconfig, COALESCE(title, ''::text)), 'A'::"char") || setweight(to_tsvector('german'::regconfig, COALESCE(slug, ''::text)), 'A'::"char")) || setweight(to_tsvector('german'::regconfig, COALESCE(public.text_array_to_string(tags, ' '::text), ''::text)), 'A'::"char")) || setweight(to_tsvector('german'::regconfig, COALESCE(app_hidden.tiptap_document_as_plain_text(content), ''::text)), 'B'::"char"))) STORED,
    CONSTRAINT valid_slug CHECK ((slug ~ '^[\w\d-]+(/[\w\d-]+)*$'::text))
);


--
-- Name: TABLE topics; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON TABLE app_public.topics IS 'A topic is a short text about something. Most topics should have the scope of a micro learning unit.';


--
-- Name: COLUMN topics.slug; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.topics.slug IS 'Each topic has a slug (a name made up of lowercase letters, digits, and hypens) to be addressed with.';


--
-- Name: COLUMN topics.title; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.topics.title IS 'Each topic has an optional title. In case of an article, this would be the headline.';


--
-- Name: COLUMN topics.license; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.topics.license IS 'Each topic can optionally be licensed. Hyperlinks are allowed.';


--
-- Name: COLUMN topics.tags; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.topics.tags IS 'Each topic can be categorized using tags.';


--
-- Name: COLUMN topics.is_visible_for; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.topics.is_visible_for IS 'Topics can be visible to anyone (`public`), to all signed-in users (`signed_in_users`), or within an organization (`organization_members`).';


--
-- Name: COLUMN topics.content; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.topics.content IS 'The topics contents as JSON. Can be converted to HTML with https://tiptap.dev/api/utilities/html';


--
-- Name: topics_content_as_plain_text(app_public.topics); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.topics_content_as_plain_text(topic app_public.topics) RETURNS text
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    AS $$
  select app_hidden.tiptap_document_as_plain_text(topic.content)
$$;


--
-- Name: topics_content_preview(app_public.topics, integer); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.topics_content_preview(topic app_public.topics, n_first_items integer DEFAULT 3) RETURNS jsonb
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    AS $_$
  select jsonb_set_lax(
    topic.content,
    '{content}',
    jsonb_path_query_array(
      topic.content, 
      '$.content[0 to $min]',
      jsonb_build_object('min', coalesce(n_first_items - 1, 2))
    ),
    create_if_missing => true,
    null_value_treatment => 'use_json_null'
  )
$_$;


--
-- Name: transfer_organization_billing_contact(uuid, uuid); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.transfer_organization_billing_contact(organization_id uuid, user_id uuid) RETURNS app_public.organizations
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
declare
 v_org app_public.organizations;
begin
  if exists(
    select 1
    from app_public.organization_memberships
    where organization_memberships.user_id = app_public.current_user_id()
    and organization_memberships.organization_id = transfer_organization_billing_contact.organization_id
    and is_owner is true
  ) then
    update app_public.organization_memberships
      set is_billing_contact = true
      where organization_memberships.organization_id = transfer_organization_billing_contact.organization_id
      and organization_memberships.user_id = transfer_organization_billing_contact.user_id;
    if found then
      update app_public.organization_memberships
        set is_billing_contact = false
        where organization_memberships.organization_id = transfer_organization_billing_contact.organization_id
        and organization_memberships.user_id <> transfer_organization_billing_contact.user_id
        and is_billing_contact = true;

      select * into v_org from app_public.organizations where id = organization_id;
      return v_org;
    end if;
  end if;
  return null;
end;
$$;


--
-- Name: transfer_organization_ownership(uuid, uuid); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.transfer_organization_ownership(organization_id uuid, user_id uuid) RETURNS app_public.organizations
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
declare
 v_org app_public.organizations;
begin
  if exists(
    select 1
    from app_public.organization_memberships
    where organization_memberships.user_id = app_public.current_user_id()
    and organization_memberships.organization_id = transfer_organization_ownership.organization_id
    and is_owner is true
  ) then
    update app_public.organization_memberships
      set is_owner = true
      where organization_memberships.organization_id = transfer_organization_ownership.organization_id
      and organization_memberships.user_id = transfer_organization_ownership.user_id;
    if found then
      update app_public.organization_memberships
        set is_owner = false
        where organization_memberships.organization_id = transfer_organization_ownership.organization_id
        and organization_memberships.user_id = app_public.current_user_id();

      select * into v_org from app_public.organizations where id = organization_id;
      return v_org;
    end if;
  end if;
  return null;
end;
$$;


--
-- Name: users_has_password(app_public.users); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.users_has_password(u app_public.users) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
  select (password_hash is not null) from app_private.user_secrets where user_secrets.user_id = u.id and u.id = app_public.current_user_id();
$$;


--
-- Name: verify_email(uuid, text); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.verify_email(user_email_id uuid, token text) RETURNS boolean
    LANGUAGE plpgsql STRICT SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
begin
  update app_public.user_emails
  set
    is_verified = true,
    is_primary = is_primary or not exists(
      select 1 from app_public.user_emails other_email where other_email.user_id = user_emails.user_id and other_email.is_primary is true
    )
  where id = user_email_id
  and exists(
    select 1 from app_private.user_email_secrets where user_email_secrets.user_email_id = user_emails.id and verification_token = token
  );
  return found;
end;
$$;


--
-- Name: FUNCTION verify_email(user_email_id uuid, token text); Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON FUNCTION app_public.verify_email(user_email_id uuid, token text) IS 'Once you have received a verification token for your email, you may call this mutation with that token to make your email verified.';


--
-- Name: notify_watchers_ddl(); Type: FUNCTION; Schema: postgraphile_watch; Owner: -
--

CREATE FUNCTION postgraphile_watch.notify_watchers_ddl() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
begin
  perform pg_notify(
    'postgraphile_watch',
    json_build_object(
      'type',
      'ddl',
      'payload',
      (select json_agg(json_build_object('schema', schema_name, 'command', command_tag)) from pg_event_trigger_ddl_commands() as x)
    )::text
  );
end;
$$;


--
-- Name: notify_watchers_drop(); Type: FUNCTION; Schema: postgraphile_watch; Owner: -
--

CREATE FUNCTION postgraphile_watch.notify_watchers_drop() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
begin
  perform pg_notify(
    'postgraphile_watch',
    json_build_object(
      'type',
      'drop',
      'payload',
      (select json_agg(distinct x.schema_name) from pg_event_trigger_dropped_objects() as x)
    )::text
  );
end;
$$;


--
-- Name: connect_pg_simple_sessions; Type: TABLE; Schema: app_private; Owner: -
--

CREATE TABLE app_private.connect_pg_simple_sessions (
    sid character varying NOT NULL,
    sess json NOT NULL,
    expire timestamp without time zone NOT NULL
);


--
-- Name: unregistered_email_password_resets; Type: TABLE; Schema: app_private; Owner: -
--

CREATE TABLE app_private.unregistered_email_password_resets (
    email public.citext NOT NULL,
    attempts integer DEFAULT 1 NOT NULL,
    latest_attempt timestamp with time zone NOT NULL
);


--
-- Name: TABLE unregistered_email_password_resets; Type: COMMENT; Schema: app_private; Owner: -
--

COMMENT ON TABLE app_private.unregistered_email_password_resets IS 'If someone tries to recover the password for an email that is not registered in our system, this table enables us to rate-limit outgoing emails to avoid spamming.';


--
-- Name: COLUMN unregistered_email_password_resets.attempts; Type: COMMENT; Schema: app_private; Owner: -
--

COMMENT ON COLUMN app_private.unregistered_email_password_resets.attempts IS 'We store the number of attempts to help us detect accounts being attacked.';


--
-- Name: COLUMN unregistered_email_password_resets.latest_attempt; Type: COMMENT; Schema: app_private; Owner: -
--

COMMENT ON COLUMN app_private.unregistered_email_password_resets.latest_attempt IS 'We store the time the last password reset was sent to this email to prevent the email getting flooded.';


--
-- Name: user_authentication_secrets; Type: TABLE; Schema: app_private; Owner: -
--

CREATE TABLE app_private.user_authentication_secrets (
    user_authentication_id uuid NOT NULL,
    details jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: user_email_secrets; Type: TABLE; Schema: app_private; Owner: -
--

CREATE TABLE app_private.user_email_secrets (
    user_email_id uuid NOT NULL,
    verification_token text,
    verification_email_sent_at timestamp with time zone,
    password_reset_email_sent_at timestamp with time zone
);


--
-- Name: TABLE user_email_secrets; Type: COMMENT; Schema: app_private; Owner: -
--

COMMENT ON TABLE app_private.user_email_secrets IS 'The contents of this table should never be visible to the user. Contains data mostly related to email verification and avoiding spamming users.';


--
-- Name: COLUMN user_email_secrets.password_reset_email_sent_at; Type: COMMENT; Schema: app_private; Owner: -
--

COMMENT ON COLUMN app_private.user_email_secrets.password_reset_email_sent_at IS 'We store the time the last password reset was sent to this email to prevent the email getting flooded.';


--
-- Name: user_secrets; Type: TABLE; Schema: app_private; Owner: -
--

CREATE TABLE app_private.user_secrets (
    user_id uuid NOT NULL,
    password_hash text,
    last_login_at timestamp with time zone DEFAULT now() NOT NULL,
    failed_password_attempts integer DEFAULT 0 NOT NULL,
    first_failed_password_attempt timestamp with time zone,
    reset_password_token text,
    reset_password_token_generated timestamp with time zone,
    failed_reset_password_attempts integer DEFAULT 0 NOT NULL,
    first_failed_reset_password_attempt timestamp with time zone,
    delete_account_token text,
    delete_account_token_generated timestamp with time zone
);


--
-- Name: TABLE user_secrets; Type: COMMENT; Schema: app_private; Owner: -
--

COMMENT ON TABLE app_private.user_secrets IS 'The contents of this table should never be visible to the user. Contains data mostly related to authentication.';


--
-- Name: files; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.files (
    id uuid DEFAULT public.uuid_generate_v1mc() NOT NULL,
    contributor_id uuid DEFAULT app_public.current_user_id(),
    uploaded_bytes integer,
    total_bytes integer,
    filename text,
    path_on_storage text,
    mime_type text,
    sha256 text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: organization_invitations; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.organization_invitations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    code text,
    user_id uuid,
    email public.citext,
    CONSTRAINT organization_invitations_check CHECK (((user_id IS NULL) <> (email IS NULL))),
    CONSTRAINT organization_invitations_check1 CHECK (((code IS NULL) = (email IS NULL)))
);


--
-- Name: organization_memberships; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.organization_memberships (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    user_id uuid NOT NULL,
    is_owner boolean DEFAULT false NOT NULL,
    is_billing_contact boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: pdf_files; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.pdf_files (
    id uuid NOT NULL,
    title text,
    pages smallint NOT NULL,
    metadata jsonb,
    content_as_plain_text text,
    fulltext_index_column tsvector GENERATED ALWAYS AS (to_tsvector('german'::regconfig, content_as_plain_text)) STORED,
    thumbnail_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: room_items; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.room_items (
    id uuid DEFAULT public.uuid_generate_v1mc() NOT NULL,
    type app_public.room_item_type DEFAULT 'MESSAGE'::app_public.room_item_type NOT NULL,
    room_id uuid NOT NULL,
    parent_id uuid,
    contributor_id uuid DEFAULT app_public.current_user_id(),
    "order" real DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    contributed_at timestamp with time zone,
    is_visible_for app_public.room_role,
    is_visible_since app_public.room_history_visibility,
    is_visible_since_date timestamp with time zone,
    topic_id uuid,
    message_body jsonb,
    CONSTRAINT is_a_valid_message CHECK (((NOT ((type = 'MESSAGE'::app_public.room_item_type) AND (contributed_at IS NOT NULL))) OR ((message_body IS NOT NULL) AND (jsonb_typeof(message_body) = 'object'::text)))),
    CONSTRAINT is_a_valid_non_message CHECK (((NOT (type <> 'MESSAGE'::app_public.room_item_type)) OR (message_body IS NULL))),
    CONSTRAINT is_a_valid_non_topic CHECK (((NOT (type <> 'TOPIC'::app_public.room_item_type)) OR (topic_id IS NULL))),
    CONSTRAINT is_a_valid_topic CHECK (((NOT ((type = 'TOPIC'::app_public.room_item_type) AND (contributed_at IS NOT NULL))) OR (topic_id IS NOT NULL)))
);


--
-- Name: TABLE room_items; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON TABLE app_public.room_items IS 'Room items are messages or materials, that are accessible within a certain room.';


--
-- Name: COLUMN room_items.type; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.room_items.type IS 'The kind of room item. There are messages, pages, files, and so on.';


--
-- Name: COLUMN room_items.parent_id; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.room_items.parent_id IS 'The items in a room can be connected to each other, basically forming one or multiple trees. For example, you can use this to keep track of conversations.';


--
-- Name: COLUMN room_items.contributor_id; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.room_items.contributor_id IS 'The id of a user who contributed the room item.';


--
-- Name: COLUMN room_items."order"; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.room_items."order" IS 'The default order is 0, but you can change it to different values to sort the items.';


--
-- Name: COLUMN room_items.is_visible_for; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.room_items.is_visible_for IS 'Decides which role can see the room item. This also applies to more powerful roles. If the value is not set, the default settings of the room will be used.';


--
-- Name: COLUMN room_items.is_visible_since; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.room_items.is_visible_since IS 'Decides if room items are always visible or only to users who subscribed before they were added. If the value is not set, the default settings of the room will be used.';


--
-- Name: room_message_attachments; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.room_message_attachments (
    id uuid DEFAULT public.uuid_generate_v1mc() NOT NULL,
    room_message_id uuid NOT NULL,
    topic_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: user_authentications; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.user_authentications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    service text NOT NULL,
    identifier text NOT NULL,
    details jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE user_authentications; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON TABLE app_public.user_authentications IS 'Contains information about the login providers this user has used, so that they may disconnect them should they wish.';


--
-- Name: COLUMN user_authentications.service; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.user_authentications.service IS 'The login service used, e.g. `twitter` or `github`.';


--
-- Name: COLUMN user_authentications.identifier; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.user_authentications.identifier IS 'A unique identifier for the user within the login service.';


--
-- Name: COLUMN user_authentications.details; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.user_authentications.details IS 'Additional profile details extracted from this login method';


--
-- Name: connect_pg_simple_sessions session_pkey; Type: CONSTRAINT; Schema: app_private; Owner: -
--

ALTER TABLE ONLY app_private.connect_pg_simple_sessions
    ADD CONSTRAINT session_pkey PRIMARY KEY (sid);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: app_private; Owner: -
--

ALTER TABLE ONLY app_private.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (uuid);


--
-- Name: unregistered_email_password_resets unregistered_email_pkey; Type: CONSTRAINT; Schema: app_private; Owner: -
--

ALTER TABLE ONLY app_private.unregistered_email_password_resets
    ADD CONSTRAINT unregistered_email_pkey PRIMARY KEY (email);


--
-- Name: user_authentication_secrets user_authentication_secrets_pkey; Type: CONSTRAINT; Schema: app_private; Owner: -
--

ALTER TABLE ONLY app_private.user_authentication_secrets
    ADD CONSTRAINT user_authentication_secrets_pkey PRIMARY KEY (user_authentication_id);


--
-- Name: user_email_secrets user_email_secrets_pkey; Type: CONSTRAINT; Schema: app_private; Owner: -
--

ALTER TABLE ONLY app_private.user_email_secrets
    ADD CONSTRAINT user_email_secrets_pkey PRIMARY KEY (user_email_id);


--
-- Name: user_secrets user_secrets_pkey; Type: CONSTRAINT; Schema: app_private; Owner: -
--

ALTER TABLE ONLY app_private.user_secrets
    ADD CONSTRAINT user_secrets_pkey PRIMARY KEY (user_id);


--
-- Name: files files_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.files
    ADD CONSTRAINT files_pkey PRIMARY KEY (id);


--
-- Name: room_subscriptions one_subscription_per_user_and_room; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.room_subscriptions
    ADD CONSTRAINT one_subscription_per_user_and_room UNIQUE (subscriber_id, room_id);


--
-- Name: organization_invitations organization_invitations_organization_id_email_key; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.organization_invitations
    ADD CONSTRAINT organization_invitations_organization_id_email_key UNIQUE (organization_id, email);


--
-- Name: organization_invitations organization_invitations_organization_id_user_id_key; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.organization_invitations
    ADD CONSTRAINT organization_invitations_organization_id_user_id_key UNIQUE (organization_id, user_id);


--
-- Name: organization_invitations organization_invitations_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.organization_invitations
    ADD CONSTRAINT organization_invitations_pkey PRIMARY KEY (id);


--
-- Name: organization_memberships organization_memberships_organization_id_user_id_key; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.organization_memberships
    ADD CONSTRAINT organization_memberships_organization_id_user_id_key UNIQUE (organization_id, user_id);


--
-- Name: organization_memberships organization_memberships_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.organization_memberships
    ADD CONSTRAINT organization_memberships_pkey PRIMARY KEY (id);


--
-- Name: organizations organizations_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.organizations
    ADD CONSTRAINT organizations_pkey PRIMARY KEY (id);


--
-- Name: organizations organizations_slug_key; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.organizations
    ADD CONSTRAINT organizations_slug_key UNIQUE (slug);


--
-- Name: pdf_files pdf_files_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.pdf_files
    ADD CONSTRAINT pdf_files_pkey PRIMARY KEY (id);


--
-- Name: room_items room_items_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.room_items
    ADD CONSTRAINT room_items_pkey PRIMARY KEY (id);


--
-- Name: room_message_attachments room_message_attachments_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.room_message_attachments
    ADD CONSTRAINT room_message_attachments_pkey PRIMARY KEY (id);


--
-- Name: room_messages room_messages_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.room_messages
    ADD CONSTRAINT room_messages_pkey PRIMARY KEY (id);


--
-- Name: room_subscriptions room_subscriptions_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.room_subscriptions
    ADD CONSTRAINT room_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: rooms rooms_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.rooms
    ADD CONSTRAINT rooms_pkey PRIMARY KEY (id);


--
-- Name: topics topics_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.topics
    ADD CONSTRAINT topics_pkey PRIMARY KEY (id);


--
-- Name: user_authentications uniq_user_authentications; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.user_authentications
    ADD CONSTRAINT uniq_user_authentications UNIQUE (service, identifier);


--
-- Name: room_message_attachments unique_powerup_exercises_per_room_message_id; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.room_message_attachments
    ADD CONSTRAINT unique_powerup_exercises_per_room_message_id UNIQUE (topic_id, room_message_id);


--
-- Name: topics unique_slug_per_organization; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.topics
    ADD CONSTRAINT unique_slug_per_organization UNIQUE NULLS NOT DISTINCT (slug, organization_id);


--
-- Name: user_authentications user_authentications_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.user_authentications
    ADD CONSTRAINT user_authentications_pkey PRIMARY KEY (id);


--
-- Name: user_emails user_emails_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.user_emails
    ADD CONSTRAINT user_emails_pkey PRIMARY KEY (id);


--
-- Name: user_emails user_emails_user_id_email_key; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.user_emails
    ADD CONSTRAINT user_emails_user_id_email_key UNIQUE (user_id, email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: sessions_user_id_idx; Type: INDEX; Schema: app_private; Owner: -
--

CREATE INDEX sessions_user_id_idx ON app_private.sessions USING btree (user_id);


--
-- Name: idx_user_emails_primary; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX idx_user_emails_primary ON app_public.user_emails USING btree (is_primary, user_id);


--
-- Name: idx_user_emails_user; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX idx_user_emails_user ON app_public.user_emails USING btree (user_id);


--
-- Name: organization_invitations_user_id_idx; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX organization_invitations_user_id_idx ON app_public.organization_invitations USING btree (user_id);


--
-- Name: organization_memberships_user_id_idx; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX organization_memberships_user_id_idx ON app_public.organization_memberships USING btree (user_id);


--
-- Name: room_items_on_contributor_id; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX room_items_on_contributor_id ON app_public.room_items USING btree (contributor_id);


--
-- Name: room_items_on_created_at; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX room_items_on_created_at ON app_public.room_items USING brin (created_at);


--
-- Name: room_items_on_parent_id; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX room_items_on_parent_id ON app_public.room_items USING btree (parent_id);


--
-- Name: room_items_on_room_id_and_order; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX room_items_on_room_id_and_order ON app_public.room_items USING btree (room_id, "order");


--
-- Name: room_items_on_updated_at; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX room_items_on_updated_at ON app_public.room_items USING brin (updated_at);


--
-- Name: room_message_attachments_on_created_at; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX room_message_attachments_on_created_at ON app_public.room_message_attachments USING brin (created_at);


--
-- Name: room_message_attachments_on_room_message_id; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX room_message_attachments_on_room_message_id ON app_public.room_message_attachments USING btree (room_message_id);


--
-- Name: room_message_attachments_on_topic_id; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX room_message_attachments_on_topic_id ON app_public.room_message_attachments USING btree (topic_id);


--
-- Name: room_messages_on_answered_message_id; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX room_messages_on_answered_message_id ON app_public.room_messages USING btree (answered_message_id);


--
-- Name: room_messages_on_created_at; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX room_messages_on_created_at ON app_public.room_messages USING brin (created_at);


--
-- Name: room_messages_on_german_fulltext; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX room_messages_on_german_fulltext ON app_public.room_messages USING gin (app_public.fulltext(ROW(id, room_id, sender_id, answered_message_id, body, language, created_at, sent_at, updated_at)));


--
-- Name: room_messages_on_room_id; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX room_messages_on_room_id ON app_public.room_messages USING btree (room_id);


--
-- Name: room_messages_on_sender_id; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX room_messages_on_sender_id ON app_public.room_messages USING btree (sender_id);


--
-- Name: room_messages_on_sent_at; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX room_messages_on_sent_at ON app_public.room_messages USING btree (sent_at);


--
-- Name: room_messages_on_updated_at; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX room_messages_on_updated_at ON app_public.room_messages USING btree (updated_at);


--
-- Name: room_subscriptionson_created_at; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX room_subscriptionson_created_at ON app_public.room_subscriptions USING brin (created_at);


--
-- Name: room_subscriptionson_room_id; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX room_subscriptionson_room_id ON app_public.room_subscriptions USING btree (room_id);


--
-- Name: room_subscriptionson_subscriber_id; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX room_subscriptionson_subscriber_id ON app_public.room_subscriptions USING btree (subscriber_id);


--
-- Name: rooms_on_created_at; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX rooms_on_created_at ON app_public.rooms USING brin (created_at);


--
-- Name: rooms_on_organization_id; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX rooms_on_organization_id ON app_public.rooms USING btree (organization_id);


--
-- Name: rooms_on_title; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX rooms_on_title ON app_public.rooms USING btree (title);


--
-- Name: rooms_on_updated_at; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX rooms_on_updated_at ON app_public.rooms USING btree (updated_at);


--
-- Name: topics_have_an_unique_slug; Type: INDEX; Schema: app_public; Owner: -
--

CREATE UNIQUE INDEX topics_have_an_unique_slug ON app_public.topics USING btree (slug) WHERE (organization_id IS NULL);


--
-- Name: topics_on_author_id; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX topics_on_author_id ON app_public.topics USING btree (author_id);


--
-- Name: topics_on_content; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX topics_on_content ON app_public.topics USING gin (content jsonb_path_ops);


--
-- Name: topics_on_created_at; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX topics_on_created_at ON app_public.topics USING brin (created_at);


--
-- Name: topics_on_fulltext_index_column; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX topics_on_fulltext_index_column ON app_public.topics USING gin (fulltext_index_column);


--
-- Name: topics_on_organization_id; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX topics_on_organization_id ON app_public.topics USING btree (organization_id);


--
-- Name: topics_on_tags; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX topics_on_tags ON app_public.topics USING gin (tags);


--
-- Name: topics_on_title; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX topics_on_title ON app_public.topics USING btree (title);


--
-- Name: topics_on_updated_at; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX topics_on_updated_at ON app_public.topics USING btree (updated_at);


--
-- Name: uniq_user_emails_primary_email; Type: INDEX; Schema: app_public; Owner: -
--

CREATE UNIQUE INDEX uniq_user_emails_primary_email ON app_public.user_emails USING btree (user_id) WHERE (is_primary IS TRUE);


--
-- Name: uniq_user_emails_verified_email; Type: INDEX; Schema: app_public; Owner: -
--

CREATE UNIQUE INDEX uniq_user_emails_verified_email ON app_public.user_emails USING btree (email) WHERE (is_verified IS TRUE);


--
-- Name: user_authentications_user_id_idx; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX user_authentications_user_id_idx ON app_public.user_authentications USING btree (user_id);


--
-- Name: users_on_fuzzy_username; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX users_on_fuzzy_username ON app_public.users USING gist (username public.gist_trgm_ops (siglen='12'));


--
-- Name: files _100_timestamps; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _100_timestamps BEFORE INSERT OR UPDATE ON app_public.files FOR EACH ROW EXECUTE FUNCTION app_private.tg__timestamps();


--
-- Name: pdf_files _100_timestamps; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _100_timestamps BEFORE INSERT OR UPDATE ON app_public.pdf_files FOR EACH ROW EXECUTE FUNCTION app_private.tg__timestamps();


--
-- Name: room_items _100_timestamps; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _100_timestamps BEFORE INSERT OR UPDATE ON app_public.room_items FOR EACH ROW EXECUTE FUNCTION app_private.tg__timestamps();


--
-- Name: room_messages _100_timestamps; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _100_timestamps BEFORE INSERT OR UPDATE ON app_public.room_messages FOR EACH ROW EXECUTE FUNCTION app_private.tg__timestamps();


--
-- Name: room_subscriptions _100_timestamps; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _100_timestamps BEFORE INSERT OR UPDATE ON app_public.room_subscriptions FOR EACH ROW EXECUTE FUNCTION app_private.tg__timestamps();


--
-- Name: rooms _100_timestamps; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _100_timestamps BEFORE INSERT OR UPDATE ON app_public.rooms FOR EACH ROW EXECUTE FUNCTION app_private.tg__timestamps();


--
-- Name: topics _100_timestamps; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _100_timestamps BEFORE INSERT OR UPDATE ON app_public.topics FOR EACH ROW EXECUTE FUNCTION app_private.tg__timestamps();


--
-- Name: user_authentications _100_timestamps; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _100_timestamps BEFORE INSERT OR UPDATE ON app_public.user_authentications FOR EACH ROW EXECUTE FUNCTION app_private.tg__timestamps();


--
-- Name: user_emails _100_timestamps; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _100_timestamps BEFORE INSERT OR UPDATE ON app_public.user_emails FOR EACH ROW EXECUTE FUNCTION app_private.tg__timestamps();


--
-- Name: users _100_timestamps; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _100_timestamps BEFORE INSERT OR UPDATE ON app_public.users FOR EACH ROW EXECUTE FUNCTION app_private.tg__timestamps();


--
-- Name: user_emails _200_forbid_existing_email; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _200_forbid_existing_email BEFORE INSERT ON app_public.user_emails FOR EACH ROW EXECUTE FUNCTION app_public.tg_user_emails__forbid_if_verified();


--
-- Name: user_emails _500_audit_added; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _500_audit_added AFTER INSERT ON app_public.user_emails FOR EACH ROW EXECUTE FUNCTION app_private.tg__add_audit_job('added_email', 'user_id', 'id', 'email');


--
-- Name: user_authentications _500_audit_removed; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _500_audit_removed AFTER DELETE ON app_public.user_authentications FOR EACH ROW EXECUTE FUNCTION app_private.tg__add_audit_job('unlinked_account', 'user_id', 'service', 'identifier');


--
-- Name: user_emails _500_audit_removed; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _500_audit_removed AFTER DELETE ON app_public.user_emails FOR EACH ROW EXECUTE FUNCTION app_private.tg__add_audit_job('removed_email', 'user_id', 'id', 'email');


--
-- Name: users _500_deletion_organization_checks_and_actions; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _500_deletion_organization_checks_and_actions BEFORE DELETE ON app_public.users FOR EACH ROW WHEN ((app_public.current_user_id() IS NOT NULL)) EXECUTE FUNCTION app_public.tg_users__deletion_organization_checks_and_actions();


--
-- Name: users _500_gql_update; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _500_gql_update AFTER UPDATE ON app_public.users FOR EACH ROW EXECUTE FUNCTION app_public.tg__graphql_subscription('userChanged', 'graphql:user:$1', 'id');


--
-- Name: user_emails _500_insert_secrets; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _500_insert_secrets AFTER INSERT ON app_public.user_emails FOR EACH ROW EXECUTE FUNCTION app_private.tg_user_email_secrets__insert_with_user_email();


--
-- Name: users _500_insert_secrets; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _500_insert_secrets AFTER INSERT ON app_public.users FOR EACH ROW EXECUTE FUNCTION app_private.tg_user_secrets__insert_with_user();


--
-- Name: user_emails _500_prevent_delete_last; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _500_prevent_delete_last AFTER DELETE ON app_public.user_emails REFERENCING OLD TABLE AS deleted FOR EACH STATEMENT EXECUTE FUNCTION app_public.tg_user_emails__prevent_delete_last_email();


--
-- Name: organization_invitations _500_send_email; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _500_send_email AFTER INSERT ON app_public.organization_invitations FOR EACH ROW EXECUTE FUNCTION app_private.tg__add_job('organization_invitations__send_invite');


--
-- Name: user_emails _500_verify_account_on_verified; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _500_verify_account_on_verified AFTER INSERT OR UPDATE OF is_verified ON app_public.user_emails FOR EACH ROW WHEN ((new.is_verified IS TRUE)) EXECUTE FUNCTION app_public.tg_user_emails__verify_account_on_verified();


--
-- Name: user_emails _900_send_verification_email; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _900_send_verification_email AFTER INSERT ON app_public.user_emails FOR EACH ROW WHEN ((new.is_verified IS FALSE)) EXECUTE FUNCTION app_private.tg__add_job('user_emails__send_verification');


--
-- Name: room_subscriptions t900_verify_role_updates_on_room_subscriptions; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE CONSTRAINT TRIGGER t900_verify_role_updates_on_room_subscriptions AFTER UPDATE ON app_public.room_subscriptions NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW WHEN ((new.role > old.role)) EXECUTE FUNCTION app_hidden.verify_role_updates_on_room_subscriptions();


--
-- Name: sessions sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: app_private; Owner: -
--

ALTER TABLE ONLY app_private.sessions
    ADD CONSTRAINT sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES app_public.users(id) ON DELETE CASCADE;


--
-- Name: user_authentication_secrets user_authentication_secrets_user_authentication_id_fkey; Type: FK CONSTRAINT; Schema: app_private; Owner: -
--

ALTER TABLE ONLY app_private.user_authentication_secrets
    ADD CONSTRAINT user_authentication_secrets_user_authentication_id_fkey FOREIGN KEY (user_authentication_id) REFERENCES app_public.user_authentications(id) ON DELETE CASCADE;


--
-- Name: user_email_secrets user_email_secrets_user_email_id_fkey; Type: FK CONSTRAINT; Schema: app_private; Owner: -
--

ALTER TABLE ONLY app_private.user_email_secrets
    ADD CONSTRAINT user_email_secrets_user_email_id_fkey FOREIGN KEY (user_email_id) REFERENCES app_public.user_emails(id) ON DELETE CASCADE;


--
-- Name: user_secrets user_secrets_user_id_fkey; Type: FK CONSTRAINT; Schema: app_private; Owner: -
--

ALTER TABLE ONLY app_private.user_secrets
    ADD CONSTRAINT user_secrets_user_id_fkey FOREIGN KEY (user_id) REFERENCES app_public.users(id) ON DELETE CASCADE;


--
-- Name: room_messages answered_message; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.room_messages
    ADD CONSTRAINT answered_message FOREIGN KEY (answered_message_id) REFERENCES app_public.room_messages(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: CONSTRAINT answered_message ON room_messages; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON CONSTRAINT answered_message ON app_public.room_messages IS '@fieldName answeredMessage
@foreignFieldName answers';


--
-- Name: topics author; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.topics
    ADD CONSTRAINT author FOREIGN KEY (author_id) REFERENCES app_public.users(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT author ON topics; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON CONSTRAINT author ON app_public.topics IS 'Each topic has an author. The field might be null when the original author has unregistered from the application.';


--
-- Name: room_items contributor; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.room_items
    ADD CONSTRAINT contributor FOREIGN KEY (contributor_id) REFERENCES app_public.users(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT contributor ON room_items; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON CONSTRAINT contributor ON app_public.room_items IS '@foreignFieldName roomItems';


--
-- Name: files contributor; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.files
    ADD CONSTRAINT contributor FOREIGN KEY (contributor_id) REFERENCES app_public.users(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: pdf_files file; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.pdf_files
    ADD CONSTRAINT file FOREIGN KEY (id) REFERENCES app_public.files(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: rooms organization; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.rooms
    ADD CONSTRAINT organization FOREIGN KEY (organization_id) REFERENCES app_public.organizations(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: CONSTRAINT organization ON rooms; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON CONSTRAINT organization ON app_public.rooms IS 'Each room can optionally belong to an organization.';


--
-- Name: topics organization; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.topics
    ADD CONSTRAINT organization FOREIGN KEY (organization_id) REFERENCES app_public.organizations(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: organization_invitations organization_invitations_organization_id_fkey; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.organization_invitations
    ADD CONSTRAINT organization_invitations_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES app_public.organizations(id) ON DELETE CASCADE;


--
-- Name: organization_invitations organization_invitations_user_id_fkey; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.organization_invitations
    ADD CONSTRAINT organization_invitations_user_id_fkey FOREIGN KEY (user_id) REFERENCES app_public.users(id) ON DELETE CASCADE;


--
-- Name: organization_memberships organization_memberships_organization_id_fkey; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.organization_memberships
    ADD CONSTRAINT organization_memberships_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES app_public.organizations(id) ON DELETE CASCADE;


--
-- Name: organization_memberships organization_memberships_user_id_fkey; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.organization_memberships
    ADD CONSTRAINT organization_memberships_user_id_fkey FOREIGN KEY (user_id) REFERENCES app_public.users(id) ON DELETE CASCADE;


--
-- Name: room_items parent; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.room_items
    ADD CONSTRAINT parent FOREIGN KEY (parent_id) REFERENCES app_public.room_items(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: CONSTRAINT parent ON room_items; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON CONSTRAINT parent ON app_public.room_items IS '@foreignFieldName children
Room items can be related in trees.';


--
-- Name: room_subscriptions room; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.room_subscriptions
    ADD CONSTRAINT room FOREIGN KEY (room_id) REFERENCES app_public.rooms(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: CONSTRAINT room ON room_subscriptions; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON CONSTRAINT room ON app_public.room_subscriptions IS '@foreignFieldName subscriptions';


--
-- Name: room_messages room; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.room_messages
    ADD CONSTRAINT room FOREIGN KEY (room_id) REFERENCES app_public.rooms(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: CONSTRAINT room ON room_messages; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON CONSTRAINT room ON app_public.room_messages IS '@foreignFieldName messages';


--
-- Name: room_items room; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.room_items
    ADD CONSTRAINT room FOREIGN KEY (room_id) REFERENCES app_public.rooms(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: CONSTRAINT room ON room_items; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON CONSTRAINT room ON app_public.room_items IS '@foreignFieldName items';


--
-- Name: room_message_attachments room_message; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.room_message_attachments
    ADD CONSTRAINT room_message FOREIGN KEY (room_message_id) REFERENCES app_public.room_messages(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: CONSTRAINT room_message ON room_message_attachments; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON CONSTRAINT room_message ON app_public.room_message_attachments IS '@fieldName message
@foreignFieldName attachments';


--
-- Name: room_subscriptions sender; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.room_subscriptions
    ADD CONSTRAINT sender FOREIGN KEY (subscriber_id) REFERENCES app_public.users(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: room_messages sender; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.room_messages
    ADD CONSTRAINT sender FOREIGN KEY (sender_id) REFERENCES app_public.users(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: pdf_files thumbnail; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.pdf_files
    ADD CONSTRAINT thumbnail FOREIGN KEY (thumbnail_id) REFERENCES app_public.files(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: room_message_attachments topic; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.room_message_attachments
    ADD CONSTRAINT topic FOREIGN KEY (topic_id) REFERENCES app_public.topics(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: room_items topic; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.room_items
    ADD CONSTRAINT topic FOREIGN KEY (topic_id) REFERENCES app_public.topics(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: user_authentications user_authentications_user_id_fkey; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.user_authentications
    ADD CONSTRAINT user_authentications_user_id_fkey FOREIGN KEY (user_id) REFERENCES app_public.users(id) ON DELETE CASCADE;


--
-- Name: user_emails user_emails_user_id_fkey; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.user_emails
    ADD CONSTRAINT user_emails_user_id_fkey FOREIGN KEY (user_id) REFERENCES app_public.users(id) ON DELETE CASCADE;


--
-- Name: connect_pg_simple_sessions; Type: ROW SECURITY; Schema: app_private; Owner: -
--

ALTER TABLE app_private.connect_pg_simple_sessions ENABLE ROW LEVEL SECURITY;

--
-- Name: sessions; Type: ROW SECURITY; Schema: app_private; Owner: -
--

ALTER TABLE app_private.sessions ENABLE ROW LEVEL SECURITY;

--
-- Name: user_authentication_secrets; Type: ROW SECURITY; Schema: app_private; Owner: -
--

ALTER TABLE app_private.user_authentication_secrets ENABLE ROW LEVEL SECURITY;

--
-- Name: user_email_secrets; Type: ROW SECURITY; Schema: app_private; Owner: -
--

ALTER TABLE app_private.user_email_secrets ENABLE ROW LEVEL SECURITY;

--
-- Name: user_secrets; Type: ROW SECURITY; Schema: app_private; Owner: -
--

ALTER TABLE app_private.user_secrets ENABLE ROW LEVEL SECURITY;

--
-- Name: room_message_attachments add_attachments; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY add_attachments ON app_public.room_message_attachments FOR INSERT WITH CHECK ((EXISTS ( SELECT
   FROM app_public.room_messages m
  WHERE ((room_message_attachments.room_message_id = m.id) AND (m.sender_id = app_public.current_user_id())))));


--
-- Name: topics admins_can_manage; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY admins_can_manage ON app_public.topics USING (( SELECT "current_user".is_admin
   FROM app_public."current_user"() "current_user"(id, username, name, avatar_url, is_admin, is_verified, created_at, updated_at, default_handling_of_notifications, sending_time_for_deferred_notifications)));


--
-- Name: topics authors_can_manage; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY authors_can_manage ON app_public.topics USING ((author_id = app_public.current_user_id()));


--
-- Name: room_message_attachments delete_attachments; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY delete_attachments ON app_public.room_message_attachments FOR DELETE USING ((EXISTS ( SELECT
   FROM app_public.room_messages m
  WHERE ((room_message_attachments.room_message_id = m.id) AND (m.sender_id = app_public.current_user_id())))));


--
-- Name: room_subscriptions delete_own; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY delete_own ON app_public.room_subscriptions FOR DELETE USING ((subscriber_id = app_public.current_user_id()));


--
-- Name: user_authentications delete_own; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY delete_own ON app_public.user_authentications FOR DELETE USING ((user_id = app_public.current_user_id()));


--
-- Name: user_emails delete_own; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY delete_own ON app_public.user_emails FOR DELETE USING ((user_id = app_public.current_user_id()));


--
-- Name: room_items hide_my_drafts_from_others; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY hide_my_drafts_from_others ON app_public.room_items AS RESTRICTIVE USING (((contributed_at IS NOT NULL) OR (contributor_id = app_public.current_user_id())));


--
-- Name: room_subscriptions insert_as_admin; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY insert_as_admin ON app_public.room_subscriptions FOR INSERT WITH CHECK ((EXISTS ( SELECT
   FROM app_public."current_user"() "current_user"(id, username, name, avatar_url, is_admin, is_verified, created_at, updated_at, default_handling_of_notifications, sending_time_for_deferred_notifications)
  WHERE "current_user".is_admin)));


--
-- Name: rooms insert_as_admin; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY insert_as_admin ON app_public.rooms FOR INSERT WITH CHECK ((EXISTS ( SELECT
   FROM app_public."current_user"() "current_user"(id, username, name, avatar_url, is_admin, is_verified, created_at, updated_at)
  WHERE "current_user".is_admin)));


--
-- Name: user_emails insert_own; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY insert_own ON app_public.user_emails FOR INSERT WITH CHECK ((user_id = app_public.current_user_id()));


--
-- Name: rooms manage_as_admin; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY manage_as_admin ON app_public.rooms USING ((id IN ( SELECT app_public.my_subscribed_room_ids(minimum_role => 'admin'::app_public.room_role) AS my_subscribed_room_ids)));


--
-- Name: room_subscriptions manage_as_moderator; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY manage_as_moderator ON app_public.room_subscriptions USING ((room_id IN ( SELECT app_public.my_subscribed_room_ids(minimum_role => 'moderator'::app_public.room_role) AS my_subscribed_room_ids)));


--
-- Name: room_items manage_by_admins; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY manage_by_admins ON app_public.room_items USING ((room_id IN ( SELECT app_public.my_subscribed_room_ids('admin'::app_public.room_role) AS my_subscribed_room_ids)));


--
-- Name: room_items manage_my_drafts; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY manage_my_drafts ON app_public.room_items USING (((contributed_at IS NULL) AND (contributor_id = app_public.current_user_id())));


--
-- Name: room_messages only_authors_should_access_their_message_drafts; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY only_authors_should_access_their_message_drafts ON app_public.room_messages AS RESTRICTIVE TO null18_cms_app_users USING (((sent_at IS NOT NULL) OR (sender_id = app_public.current_user_id())));


--
-- Name: organization_invitations; Type: ROW SECURITY; Schema: app_public; Owner: -
--

ALTER TABLE app_public.organization_invitations ENABLE ROW LEVEL SECURITY;

--
-- Name: organization_memberships; Type: ROW SECURITY; Schema: app_public; Owner: -
--

ALTER TABLE app_public.organization_memberships ENABLE ROW LEVEL SECURITY;

--
-- Name: organizations; Type: ROW SECURITY; Schema: app_public; Owner: -
--

ALTER TABLE app_public.organizations ENABLE ROW LEVEL SECURITY;

--
-- Name: room_messages require_messages_from_current_user; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY require_messages_from_current_user ON app_public.room_messages AS RESTRICTIVE FOR INSERT TO null18_cms_app_users WITH CHECK ((sender_id = app_public.current_user_id()));


--
-- Name: room_items; Type: ROW SECURITY; Schema: app_public; Owner: -
--

ALTER TABLE app_public.room_items ENABLE ROW LEVEL SECURITY;

--
-- Name: room_message_attachments; Type: ROW SECURITY; Schema: app_public; Owner: -
--

ALTER TABLE app_public.room_message_attachments ENABLE ROW LEVEL SECURITY;

--
-- Name: room_messages; Type: ROW SECURITY; Schema: app_public; Owner: -
--

ALTER TABLE app_public.room_messages ENABLE ROW LEVEL SECURITY;

--
-- Name: room_subscriptions; Type: ROW SECURITY; Schema: app_public; Owner: -
--

ALTER TABLE app_public.room_subscriptions ENABLE ROW LEVEL SECURITY;

--
-- Name: rooms; Type: ROW SECURITY; Schema: app_public; Owner: -
--

ALTER TABLE app_public.rooms ENABLE ROW LEVEL SECURITY;

--
-- Name: users select_all; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY select_all ON app_public.users FOR SELECT USING (true);


--
-- Name: room_message_attachments select_attachments; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY select_attachments ON app_public.room_message_attachments FOR SELECT USING ((EXISTS ( SELECT
   FROM app_public.room_messages m
  WHERE (room_message_attachments.room_message_id = m.id))));


--
-- Name: room_messages select_if_public_or_subscribed; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY select_if_public_or_subscribed ON app_public.room_messages FOR SELECT USING ((EXISTS ( SELECT
   FROM (app_public.rooms r
     LEFT JOIN LATERAL app_public.my_room_subscription(r.*) s(id, room_id, subscriber_id, role, notifications, created_at, updated_at) ON (true))
  WHERE ((room_messages.room_id = r.id) AND ((r.items_are_visible_since >= 'always'::app_public.room_history_visibility) OR ((r.items_are_visible_since >= 'specified_date'::app_public.room_history_visibility) AND (room_messages.created_at >= (r.items_are_visible_since_date - r.extend_visibility_of_items_by))) OR ((r.items_are_visible_since >= 'subscription'::app_public.room_history_visibility) AND (room_messages.created_at >= (s.created_at - r.extend_visibility_of_items_by))))))));


--
-- Name: rooms select_if_signed_in; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY select_if_signed_in ON app_public.rooms FOR SELECT USING (((is_visible_for = 'signed_in_users'::app_public.room_visibility) AND (app_public.current_user_id() IS NOT NULL)));


--
-- Name: topics select_if_signed_in; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY select_if_signed_in ON app_public.topics FOR SELECT USING (((is_visible_for = 'signed_in_users'::app_public.topic_visibility) AND (app_public.current_user_id() IS NOT NULL)));


--
-- Name: organization_memberships select_invited; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY select_invited ON app_public.organization_memberships FOR SELECT USING ((organization_id IN ( SELECT app_public.current_user_invited_organization_ids() AS current_user_invited_organization_ids)));


--
-- Name: organizations select_invited; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY select_invited ON app_public.organizations FOR SELECT USING ((id IN ( SELECT app_public.current_user_invited_organization_ids() AS current_user_invited_organization_ids)));


--
-- Name: organization_memberships select_member; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY select_member ON app_public.organization_memberships FOR SELECT USING ((organization_id IN ( SELECT app_public.current_user_member_organization_ids() AS current_user_member_organization_ids)));


--
-- Name: organizations select_member; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY select_member ON app_public.organizations FOR SELECT USING ((id IN ( SELECT app_public.current_user_member_organization_ids() AS current_user_member_organization_ids)));


--
-- Name: room_messages select_my_drafts; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY select_my_drafts ON app_public.room_messages FOR SELECT USING (((sent_at IS NULL) AND (sender_id = app_public.current_user_id())));


--
-- Name: room_subscriptions select_own; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY select_own ON app_public.room_subscriptions FOR SELECT USING ((subscriber_id = app_public.current_user_id()));


--
-- Name: user_authentications select_own; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY select_own ON app_public.user_authentications FOR SELECT USING ((user_id = app_public.current_user_id()));


--
-- Name: user_emails select_own; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY select_own ON app_public.user_emails FOR SELECT USING ((user_id = app_public.current_user_id()));


--
-- Name: room_subscriptions select_peers; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY select_peers ON app_public.room_subscriptions FOR SELECT USING ((room_id IN ( SELECT app_public.my_subscribed_room_ids() AS my_subscribed_room_ids)));


--
-- Name: rooms select_public; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY select_public ON app_public.rooms FOR SELECT USING ((is_visible_for = 'public'::app_public.room_visibility));


--
-- Name: topics select_public; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY select_public ON app_public.topics FOR SELECT USING ((is_visible_for = 'public'::app_public.topic_visibility));


--
-- Name: rooms select_within_organization; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY select_within_organization ON app_public.rooms FOR SELECT USING (((is_visible_for = 'organization_members'::app_public.room_visibility) AND (organization_id IN ( SELECT app_public.current_user_member_organization_ids() AS current_user_member_organization_ids))));


--
-- Name: topics select_within_organization; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY select_within_organization ON app_public.topics FOR SELECT USING (((is_visible_for = 'organization_members'::app_public.topic_visibility) AND (organization_id IN ( SELECT app_public.current_user_member_organization_ids() AS current_user_member_organization_ids))));


--
-- Name: room_messages send_messages_to_public_rooms; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY send_messages_to_public_rooms ON app_public.room_messages FOR INSERT WITH CHECK ((room_id IN ( SELECT rooms.id
   FROM app_public.rooms
  WHERE (rooms.is_visible_for >= 'public'::app_public.room_visibility))));


--
-- Name: room_items show_mine; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY show_mine ON app_public.room_items FOR SELECT USING ((contributor_id = app_public.current_user_id()));


--
-- Name: room_items show_others_to_members; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY show_others_to_members ON app_public.room_items FOR SELECT USING ((EXISTS ( SELECT
   FROM (app_public.rooms r
     LEFT JOIN LATERAL app_public.my_room_subscription(in_room => r.*) s(id, room_id, subscriber_id, role, notifications, created_at, updated_at) ON (true))
  WHERE ((r.id = room_items.room_id) AND (s.role IS DISTINCT FROM 'banned'::app_public.room_role) AND
        CASE COALESCE(room_items.is_visible_for, r.items_are_visible_for)
            WHEN 'public'::app_public.room_role THEN true
            ELSE (s.role >= COALESCE(room_items.is_visible_for, r.items_are_visible_for))
        END AND
        CASE COALESCE(room_items.is_visible_since, r.items_are_visible_since)
            WHEN 'always'::app_public.room_history_visibility THEN true
            WHEN 'specified_date'::app_public.room_history_visibility THEN (room_items.contributed_at >= COALESCE(room_items.is_visible_since_date, r.items_are_visible_since_date))
            ELSE (room_items.contributed_at >= s.created_at)
        END))));


--
-- Name: rooms show_subscribed; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY show_subscribed ON app_public.rooms FOR SELECT USING ((id IN ( SELECT app_public.my_subscribed_room_ids(minimum_role => 'banned'::app_public.room_role) AS my_subscribed_room_ids)));


--
-- Name: room_subscriptions subscribe_rooms; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY subscribe_rooms ON app_public.room_subscriptions FOR INSERT WITH CHECK ((EXISTS ( SELECT
   FROM app_public.rooms r
  WHERE ((room_subscriptions.room_id = r.id) AND (room_subscriptions.subscriber_id = app_public.current_user_id()) AND (((r.is_visible_for >= 'public'::app_public.room_visibility) AND (room_subscriptions.role <= 'member'::app_public.room_role)) OR ((r.is_visible_for <= 'public'::app_public.room_visibility) AND (room_subscriptions.role <= 'prospect'::app_public.room_role)) OR (r.created_at = room_subscriptions.created_at) OR (app_public.n_room_subscriptions(r.*) < 1))))));


--
-- Name: topics; Type: ROW SECURITY; Schema: app_public; Owner: -
--

ALTER TABLE app_public.topics ENABLE ROW LEVEL SECURITY;

--
-- Name: room_items update_mine; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY update_mine ON app_public.room_items FOR UPDATE USING ((contributor_id = app_public.current_user_id()));


--
-- Name: room_messages update_own_messages; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY update_own_messages ON app_public.room_messages FOR UPDATE USING ((sender_id = app_public.current_user_id()));


--
-- Name: organizations update_owner; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY update_owner ON app_public.organizations FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM app_public.organization_memberships
  WHERE ((organization_memberships.organization_id = organizations.id) AND (organization_memberships.user_id = app_public.current_user_id()) AND (organization_memberships.is_owner IS TRUE)))));


--
-- Name: users update_self; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY update_self ON app_public.users FOR UPDATE USING ((id = app_public.current_user_id()));


--
-- Name: user_authentications; Type: ROW SECURITY; Schema: app_public; Owner: -
--

ALTER TABLE app_public.user_authentications ENABLE ROW LEVEL SECURITY;

--
-- Name: user_emails; Type: ROW SECURITY; Schema: app_public; Owner: -
--

ALTER TABLE app_public.user_emails ENABLE ROW LEVEL SECURITY;

--
-- Name: users; Type: ROW SECURITY; Schema: app_public; Owner: -
--

ALTER TABLE app_public.users ENABLE ROW LEVEL SECURITY;

--
-- Name: SCHEMA app_hidden; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA app_hidden TO null18_cms_app_users;


--
-- Name: SCHEMA app_public; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA app_public TO null18_cms_app_users;


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: -
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO null18_cms_app_users;


--
-- Name: TYPE textsearchable_entity; Type: ACL; Schema: app_public; Owner: -
--

GRANT ALL ON TYPE app_public.textsearchable_entity TO null18_cms_app_users;


--
-- Name: TYPE textsearch_match; Type: ACL; Schema: app_public; Owner: -
--

GRANT ALL ON TYPE app_public.textsearch_match TO null18_cms_app_users;


--
-- Name: FUNCTION tiptap_document_as_plain_text(document jsonb); Type: ACL; Schema: app_hidden; Owner: -
--

REVOKE ALL ON FUNCTION app_hidden.tiptap_document_as_plain_text(document jsonb) FROM PUBLIC;
GRANT ALL ON FUNCTION app_hidden.tiptap_document_as_plain_text(document jsonb) TO null18_cms_app_users;


--
-- Name: FUNCTION verify_role_updates_on_room_subscriptions(); Type: ACL; Schema: app_hidden; Owner: -
--

REVOKE ALL ON FUNCTION app_hidden.verify_role_updates_on_room_subscriptions() FROM PUBLIC;
GRANT ALL ON FUNCTION app_hidden.verify_role_updates_on_room_subscriptions() TO null18_cms_app_users;


--
-- Name: FUNCTION assert_valid_password(new_password text); Type: ACL; Schema: app_private; Owner: -
--

REVOKE ALL ON FUNCTION app_private.assert_valid_password(new_password text) FROM PUBLIC;


--
-- Name: TABLE users; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT ON TABLE app_public.users TO null18_cms_app_users;


--
-- Name: COLUMN users.username; Type: ACL; Schema: app_public; Owner: -
--

GRANT UPDATE(username) ON TABLE app_public.users TO null18_cms_app_users;


--
-- Name: COLUMN users.name; Type: ACL; Schema: app_public; Owner: -
--

GRANT UPDATE(name) ON TABLE app_public.users TO null18_cms_app_users;


--
-- Name: COLUMN users.avatar_url; Type: ACL; Schema: app_public; Owner: -
--

GRANT UPDATE(avatar_url) ON TABLE app_public.users TO null18_cms_app_users;


--
-- Name: COLUMN users.default_handling_of_notifications; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(default_handling_of_notifications),UPDATE(default_handling_of_notifications) ON TABLE app_public.users TO null18_cms_app_users;


--
-- Name: COLUMN users.sending_time_for_deferred_notifications; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(sending_time_for_deferred_notifications),UPDATE(sending_time_for_deferred_notifications) ON TABLE app_public.users TO null18_cms_app_users;


--
-- Name: FUNCTION link_or_register_user(f_user_id uuid, f_service character varying, f_identifier character varying, f_profile json, f_auth_details json); Type: ACL; Schema: app_private; Owner: -
--

REVOKE ALL ON FUNCTION app_private.link_or_register_user(f_user_id uuid, f_service character varying, f_identifier character varying, f_profile json, f_auth_details json) FROM PUBLIC;


--
-- Name: FUNCTION login(username public.citext, password text); Type: ACL; Schema: app_private; Owner: -
--

REVOKE ALL ON FUNCTION app_private.login(username public.citext, password text) FROM PUBLIC;


--
-- Name: FUNCTION really_create_user(username public.citext, email text, email_is_verified boolean, name text, avatar_url text, password text); Type: ACL; Schema: app_private; Owner: -
--

REVOKE ALL ON FUNCTION app_private.really_create_user(username public.citext, email text, email_is_verified boolean, name text, avatar_url text, password text) FROM PUBLIC;


--
-- Name: FUNCTION register_user(f_service character varying, f_identifier character varying, f_profile json, f_auth_details json, f_email_is_verified boolean); Type: ACL; Schema: app_private; Owner: -
--

REVOKE ALL ON FUNCTION app_private.register_user(f_service character varying, f_identifier character varying, f_profile json, f_auth_details json, f_email_is_verified boolean) FROM PUBLIC;


--
-- Name: FUNCTION reset_password(user_id uuid, reset_token text, new_password text); Type: ACL; Schema: app_private; Owner: -
--

REVOKE ALL ON FUNCTION app_private.reset_password(user_id uuid, reset_token text, new_password text) FROM PUBLIC;


--
-- Name: FUNCTION tg__add_audit_job(); Type: ACL; Schema: app_private; Owner: -
--

REVOKE ALL ON FUNCTION app_private.tg__add_audit_job() FROM PUBLIC;


--
-- Name: FUNCTION tg__add_job(); Type: ACL; Schema: app_private; Owner: -
--

REVOKE ALL ON FUNCTION app_private.tg__add_job() FROM PUBLIC;


--
-- Name: FUNCTION tg__timestamps(); Type: ACL; Schema: app_private; Owner: -
--

REVOKE ALL ON FUNCTION app_private.tg__timestamps() FROM PUBLIC;


--
-- Name: FUNCTION tg_user_email_secrets__insert_with_user_email(); Type: ACL; Schema: app_private; Owner: -
--

REVOKE ALL ON FUNCTION app_private.tg_user_email_secrets__insert_with_user_email() FROM PUBLIC;


--
-- Name: FUNCTION tg_user_secrets__insert_with_user(); Type: ACL; Schema: app_private; Owner: -
--

REVOKE ALL ON FUNCTION app_private.tg_user_secrets__insert_with_user() FROM PUBLIC;


--
-- Name: FUNCTION accept_invitation_to_organization(invitation_id uuid, code text); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.accept_invitation_to_organization(invitation_id uuid, code text) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.accept_invitation_to_organization(invitation_id uuid, code text) TO null18_cms_app_users;


--
-- Name: FUNCTION change_password(old_password text, new_password text); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.change_password(old_password text, new_password text) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.change_password(old_password text, new_password text) TO null18_cms_app_users;


--
-- Name: FUNCTION confirm_account_deletion(token text); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.confirm_account_deletion(token text) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.confirm_account_deletion(token text) TO null18_cms_app_users;


--
-- Name: TABLE organizations; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT ON TABLE app_public.organizations TO null18_cms_app_users;


--
-- Name: COLUMN organizations.slug; Type: ACL; Schema: app_public; Owner: -
--

GRANT UPDATE(slug) ON TABLE app_public.organizations TO null18_cms_app_users;


--
-- Name: COLUMN organizations.name; Type: ACL; Schema: app_public; Owner: -
--

GRANT UPDATE(name) ON TABLE app_public.organizations TO null18_cms_app_users;


--
-- Name: FUNCTION create_organization(slug public.citext, name text); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.create_organization(slug public.citext, name text) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.create_organization(slug public.citext, name text) TO null18_cms_app_users;


--
-- Name: FUNCTION current_session_id(); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.current_session_id() FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.current_session_id() TO null18_cms_app_users;


--
-- Name: FUNCTION "current_user"(); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public."current_user"() FROM PUBLIC;
GRANT ALL ON FUNCTION app_public."current_user"() TO null18_cms_app_users;


--
-- Name: FUNCTION current_user_first_owned_organization_id(); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.current_user_first_owned_organization_id() FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.current_user_first_owned_organization_id() TO null18_cms_app_users;


--
-- Name: FUNCTION current_user_id(); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.current_user_id() FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.current_user_id() TO null18_cms_app_users;


--
-- Name: FUNCTION current_user_invited_organization_ids(); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.current_user_invited_organization_ids() FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.current_user_invited_organization_ids() TO null18_cms_app_users;


--
-- Name: FUNCTION current_user_member_organization_ids(); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.current_user_member_organization_ids() FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.current_user_member_organization_ids() TO null18_cms_app_users;


--
-- Name: FUNCTION delete_organization(organization_id uuid); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.delete_organization(organization_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.delete_organization(organization_id uuid) TO null18_cms_app_users;


--
-- Name: TABLE room_messages; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT,DELETE ON TABLE app_public.room_messages TO null18_cms_app_users;


--
-- Name: COLUMN room_messages.room_id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(room_id) ON TABLE app_public.room_messages TO null18_cms_app_users;


--
-- Name: COLUMN room_messages.sender_id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(sender_id) ON TABLE app_public.room_messages TO null18_cms_app_users;


--
-- Name: COLUMN room_messages.answered_message_id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(answered_message_id),UPDATE(answered_message_id) ON TABLE app_public.room_messages TO null18_cms_app_users;


--
-- Name: COLUMN room_messages.body; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(body),UPDATE(body) ON TABLE app_public.room_messages TO null18_cms_app_users;


--
-- Name: COLUMN room_messages.language; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(language),UPDATE(language) ON TABLE app_public.room_messages TO null18_cms_app_users;


--
-- Name: COLUMN room_messages.sent_at; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(sent_at),UPDATE(sent_at) ON TABLE app_public.room_messages TO null18_cms_app_users;


--
-- Name: FUNCTION fetch_draft_in_room(room_id uuid); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.fetch_draft_in_room(room_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.fetch_draft_in_room(room_id uuid) TO null18_cms_app_users;


--
-- Name: FUNCTION forgot_password(email public.citext); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.forgot_password(email public.citext) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.forgot_password(email public.citext) TO null18_cms_app_users;


--
-- Name: FUNCTION fulltext(message app_public.room_messages); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.fulltext(message app_public.room_messages) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.fulltext(message app_public.room_messages) TO null18_cms_app_users;


--
-- Name: FUNCTION global_search(term text, entities app_public.textsearchable_entity[]); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.global_search(term text, entities app_public.textsearchable_entity[]) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.global_search(term text, entities app_public.textsearchable_entity[]) TO null18_cms_app_users;


--
-- Name: FUNCTION invite_to_organization(organization_id uuid, username public.citext, email public.citext); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.invite_to_organization(organization_id uuid, username public.citext, email public.citext) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.invite_to_organization(organization_id uuid, username public.citext, email public.citext) TO null18_cms_app_users;


--
-- Name: TABLE rooms; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT,DELETE ON TABLE app_public.rooms TO null18_cms_app_users;


--
-- Name: COLUMN rooms.title; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(title),UPDATE(title) ON TABLE app_public.rooms TO null18_cms_app_users;


--
-- Name: COLUMN rooms.abstract; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(abstract),UPDATE(abstract) ON TABLE app_public.rooms TO null18_cms_app_users;


--
-- Name: COLUMN rooms.is_visible_for; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(is_visible_for),UPDATE(is_visible_for) ON TABLE app_public.rooms TO null18_cms_app_users;


--
-- Name: COLUMN rooms.items_are_visible_since; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(items_are_visible_since),UPDATE(items_are_visible_since) ON TABLE app_public.rooms TO null18_cms_app_users;


--
-- Name: COLUMN rooms.is_anonymous_posting_allowed; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(is_anonymous_posting_allowed),UPDATE(is_anonymous_posting_allowed) ON TABLE app_public.rooms TO null18_cms_app_users;


--
-- Name: FUNCTION latest_message(room app_public.rooms); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.latest_message(room app_public.rooms) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.latest_message(room app_public.rooms) TO null18_cms_app_users;


--
-- Name: FUNCTION logout(); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.logout() FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.logout() TO null18_cms_app_users;


--
-- Name: TABLE user_emails; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT,DELETE ON TABLE app_public.user_emails TO null18_cms_app_users;


--
-- Name: COLUMN user_emails.email; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(email) ON TABLE app_public.user_emails TO null18_cms_app_users;


--
-- Name: FUNCTION make_email_primary(email_id uuid); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.make_email_primary(email_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.make_email_primary(email_id uuid) TO null18_cms_app_users;


--
-- Name: FUNCTION my_first_interaction(room app_public.rooms); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.my_first_interaction(room app_public.rooms) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.my_first_interaction(room app_public.rooms) TO null18_cms_app_users;


--
-- Name: TABLE room_subscriptions; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT,DELETE ON TABLE app_public.room_subscriptions TO null18_cms_app_users;


--
-- Name: COLUMN room_subscriptions.room_id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(room_id) ON TABLE app_public.room_subscriptions TO null18_cms_app_users;


--
-- Name: COLUMN room_subscriptions.subscriber_id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(subscriber_id) ON TABLE app_public.room_subscriptions TO null18_cms_app_users;


--
-- Name: COLUMN room_subscriptions.role; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(role),UPDATE(role) ON TABLE app_public.room_subscriptions TO null18_cms_app_users;


--
-- Name: COLUMN room_subscriptions.notifications; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(notifications),UPDATE(notifications) ON TABLE app_public.room_subscriptions TO null18_cms_app_users;


--
-- Name: FUNCTION my_room_subscription(in_room app_public.rooms); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.my_room_subscription(in_room app_public.rooms) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.my_room_subscription(in_room app_public.rooms) TO null18_cms_app_users;


--
-- Name: FUNCTION my_room_subscription_id(in_room app_public.rooms); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.my_room_subscription_id(in_room app_public.rooms) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.my_room_subscription_id(in_room app_public.rooms) TO null18_cms_app_users;


--
-- Name: FUNCTION my_room_subscriptions(minimum_role app_public.room_role); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.my_room_subscriptions(minimum_role app_public.room_role) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.my_room_subscriptions(minimum_role app_public.room_role) TO null18_cms_app_users;


--
-- Name: FUNCTION my_subscribed_room_ids(minimum_role app_public.room_role); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.my_subscribed_room_ids(minimum_role app_public.room_role) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.my_subscribed_room_ids(minimum_role app_public.room_role) TO null18_cms_app_users;


--
-- Name: FUNCTION n_room_subscriptions(room app_public.rooms, min_role app_public.room_role); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.n_room_subscriptions(room app_public.rooms, min_role app_public.room_role) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.n_room_subscriptions(room app_public.rooms, min_role app_public.room_role) TO null18_cms_app_users;


--
-- Name: FUNCTION organization_for_invitation(invitation_id uuid, code text); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.organization_for_invitation(invitation_id uuid, code text) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.organization_for_invitation(invitation_id uuid, code text) TO null18_cms_app_users;


--
-- Name: FUNCTION organizations_current_user_is_billing_contact(org app_public.organizations); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.organizations_current_user_is_billing_contact(org app_public.organizations) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.organizations_current_user_is_billing_contact(org app_public.organizations) TO null18_cms_app_users;


--
-- Name: FUNCTION organizations_current_user_is_owner(org app_public.organizations); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.organizations_current_user_is_owner(org app_public.organizations) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.organizations_current_user_is_owner(org app_public.organizations) TO null18_cms_app_users;


--
-- Name: FUNCTION remove_from_organization(organization_id uuid, user_id uuid); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.remove_from_organization(organization_id uuid, user_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.remove_from_organization(organization_id uuid, user_id uuid) TO null18_cms_app_users;


--
-- Name: FUNCTION request_account_deletion(); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.request_account_deletion() FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.request_account_deletion() TO null18_cms_app_users;


--
-- Name: FUNCTION resend_email_verification_code(email_id uuid); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.resend_email_verification_code(email_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.resend_email_verification_code(email_id uuid) TO null18_cms_app_users;


--
-- Name: FUNCTION send_room_message(draft_id uuid, OUT room_message app_public.room_messages); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.send_room_message(draft_id uuid, OUT room_message app_public.room_messages) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.send_room_message(draft_id uuid, OUT room_message app_public.room_messages) TO null18_cms_app_users;


--
-- Name: FUNCTION tg__graphql_subscription(); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.tg__graphql_subscription() FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.tg__graphql_subscription() TO null18_cms_app_users;


--
-- Name: FUNCTION tg_user_emails__forbid_if_verified(); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.tg_user_emails__forbid_if_verified() FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.tg_user_emails__forbid_if_verified() TO null18_cms_app_users;


--
-- Name: FUNCTION tg_user_emails__prevent_delete_last_email(); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.tg_user_emails__prevent_delete_last_email() FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.tg_user_emails__prevent_delete_last_email() TO null18_cms_app_users;


--
-- Name: FUNCTION tg_user_emails__verify_account_on_verified(); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.tg_user_emails__verify_account_on_verified() FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.tg_user_emails__verify_account_on_verified() TO null18_cms_app_users;


--
-- Name: FUNCTION tg_users__deletion_organization_checks_and_actions(); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.tg_users__deletion_organization_checks_and_actions() FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.tg_users__deletion_organization_checks_and_actions() TO null18_cms_app_users;


--
-- Name: TABLE topics; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT,DELETE ON TABLE app_public.topics TO null18_cms_app_users;


--
-- Name: COLUMN topics.author_id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(author_id),UPDATE(author_id) ON TABLE app_public.topics TO null18_cms_app_users;


--
-- Name: COLUMN topics.organization_id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(organization_id),UPDATE(organization_id) ON TABLE app_public.topics TO null18_cms_app_users;


--
-- Name: COLUMN topics.slug; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(slug),UPDATE(slug) ON TABLE app_public.topics TO null18_cms_app_users;


--
-- Name: COLUMN topics.title; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(title),UPDATE(title) ON TABLE app_public.topics TO null18_cms_app_users;


--
-- Name: COLUMN topics.license; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(license),UPDATE(license) ON TABLE app_public.topics TO null18_cms_app_users;


--
-- Name: COLUMN topics.is_visible_for; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(is_visible_for),UPDATE(is_visible_for) ON TABLE app_public.topics TO null18_cms_app_users;


--
-- Name: COLUMN topics.content; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(content),UPDATE(content) ON TABLE app_public.topics TO null18_cms_app_users;


--
-- Name: FUNCTION topics_content_as_plain_text(topic app_public.topics); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.topics_content_as_plain_text(topic app_public.topics) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.topics_content_as_plain_text(topic app_public.topics) TO null18_cms_app_users;


--
-- Name: FUNCTION topics_content_preview(topic app_public.topics, n_first_items integer); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.topics_content_preview(topic app_public.topics, n_first_items integer) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.topics_content_preview(topic app_public.topics, n_first_items integer) TO null18_cms_app_users;


--
-- Name: FUNCTION transfer_organization_billing_contact(organization_id uuid, user_id uuid); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.transfer_organization_billing_contact(organization_id uuid, user_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.transfer_organization_billing_contact(organization_id uuid, user_id uuid) TO null18_cms_app_users;


--
-- Name: FUNCTION transfer_organization_ownership(organization_id uuid, user_id uuid); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.transfer_organization_ownership(organization_id uuid, user_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.transfer_organization_ownership(organization_id uuid, user_id uuid) TO null18_cms_app_users;


--
-- Name: FUNCTION users_has_password(u app_public.users); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.users_has_password(u app_public.users) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.users_has_password(u app_public.users) TO null18_cms_app_users;


--
-- Name: FUNCTION verify_email(user_email_id uuid, token text); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.verify_email(user_email_id uuid, token text) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.verify_email(user_email_id uuid, token text) TO null18_cms_app_users;


--
-- Name: TABLE files; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT,DELETE ON TABLE app_public.files TO null18_cms_app_users;


--
-- Name: COLUMN files.id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(id),UPDATE(id) ON TABLE app_public.files TO null18_cms_app_users;


--
-- Name: COLUMN files.contributor_id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(contributor_id) ON TABLE app_public.files TO null18_cms_app_users;


--
-- Name: COLUMN files.uploaded_bytes; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(uploaded_bytes),UPDATE(uploaded_bytes) ON TABLE app_public.files TO null18_cms_app_users;


--
-- Name: COLUMN files.total_bytes; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(total_bytes),UPDATE(total_bytes) ON TABLE app_public.files TO null18_cms_app_users;


--
-- Name: COLUMN files.filename; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(filename),UPDATE(filename) ON TABLE app_public.files TO null18_cms_app_users;


--
-- Name: COLUMN files.mime_type; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(mime_type),UPDATE(mime_type) ON TABLE app_public.files TO null18_cms_app_users;


--
-- Name: TABLE organization_memberships; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT ON TABLE app_public.organization_memberships TO null18_cms_app_users;


--
-- Name: TABLE pdf_files; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT,DELETE ON TABLE app_public.pdf_files TO null18_cms_app_users;


--
-- Name: COLUMN pdf_files.id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(id),UPDATE(id) ON TABLE app_public.pdf_files TO null18_cms_app_users;


--
-- Name: COLUMN pdf_files.title; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(title),UPDATE(title) ON TABLE app_public.pdf_files TO null18_cms_app_users;


--
-- Name: COLUMN pdf_files.pages; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(pages),UPDATE(pages) ON TABLE app_public.pdf_files TO null18_cms_app_users;


--
-- Name: COLUMN pdf_files.metadata; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(metadata),UPDATE(metadata) ON TABLE app_public.pdf_files TO null18_cms_app_users;


--
-- Name: COLUMN pdf_files.content_as_plain_text; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(content_as_plain_text),UPDATE(content_as_plain_text) ON TABLE app_public.pdf_files TO null18_cms_app_users;


--
-- Name: COLUMN pdf_files.thumbnail_id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(thumbnail_id),UPDATE(thumbnail_id) ON TABLE app_public.pdf_files TO null18_cms_app_users;


--
-- Name: TABLE room_items; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT,DELETE ON TABLE app_public.room_items TO null18_cms_app_users;


--
-- Name: COLUMN room_items.type; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(type) ON TABLE app_public.room_items TO null18_cms_app_users;


--
-- Name: COLUMN room_items.room_id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(room_id) ON TABLE app_public.room_items TO null18_cms_app_users;


--
-- Name: COLUMN room_items.parent_id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(parent_id) ON TABLE app_public.room_items TO null18_cms_app_users;


--
-- Name: COLUMN room_items.contributor_id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(contributor_id) ON TABLE app_public.room_items TO null18_cms_app_users;


--
-- Name: COLUMN room_items."order"; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT("order"),UPDATE("order") ON TABLE app_public.room_items TO null18_cms_app_users;


--
-- Name: COLUMN room_items.contributed_at; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(contributed_at),UPDATE(contributed_at) ON TABLE app_public.room_items TO null18_cms_app_users;


--
-- Name: COLUMN room_items.is_visible_for; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(is_visible_for),UPDATE(is_visible_for) ON TABLE app_public.room_items TO null18_cms_app_users;


--
-- Name: COLUMN room_items.is_visible_since; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(is_visible_since),UPDATE(is_visible_since) ON TABLE app_public.room_items TO null18_cms_app_users;


--
-- Name: COLUMN room_items.is_visible_since_date; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(is_visible_since_date),UPDATE(is_visible_since_date) ON TABLE app_public.room_items TO null18_cms_app_users;


--
-- Name: COLUMN room_items.topic_id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(topic_id),UPDATE(topic_id) ON TABLE app_public.room_items TO null18_cms_app_users;


--
-- Name: COLUMN room_items.message_body; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(message_body),UPDATE(message_body) ON TABLE app_public.room_items TO null18_cms_app_users;


--
-- Name: TABLE room_message_attachments; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT,DELETE ON TABLE app_public.room_message_attachments TO null18_cms_app_users;


--
-- Name: COLUMN room_message_attachments.id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(id) ON TABLE app_public.room_message_attachments TO null18_cms_app_users;


--
-- Name: COLUMN room_message_attachments.room_message_id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(room_message_id) ON TABLE app_public.room_message_attachments TO null18_cms_app_users;


--
-- Name: COLUMN room_message_attachments.topic_id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(topic_id) ON TABLE app_public.room_message_attachments TO null18_cms_app_users;


--
-- Name: TABLE user_authentications; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT,DELETE ON TABLE app_public.user_authentications TO null18_cms_app_users;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: app_hidden; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE null18_cms_owner IN SCHEMA app_hidden GRANT SELECT,USAGE ON SEQUENCES TO null18_cms_app_users;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: app_hidden; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE null18_cms_owner IN SCHEMA app_hidden GRANT ALL ON FUNCTIONS TO null18_cms_app_users;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: app_public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE null18_cms_owner IN SCHEMA app_public GRANT SELECT,USAGE ON SEQUENCES TO null18_cms_app_users;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: app_public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE null18_cms_owner IN SCHEMA app_public GRANT ALL ON FUNCTIONS TO null18_cms_app_users;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE null18_cms_owner IN SCHEMA public GRANT SELECT,USAGE ON SEQUENCES TO null18_cms_app_users;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE null18_cms_owner IN SCHEMA public GRANT ALL ON FUNCTIONS TO null18_cms_app_users;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: -; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE null18_cms_owner REVOKE ALL ON FUNCTIONS FROM PUBLIC;


--
-- Name: postgraphile_watch_ddl; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER postgraphile_watch_ddl ON ddl_command_end
         WHEN TAG IN ('ALTER AGGREGATE', 'ALTER DOMAIN', 'ALTER EXTENSION', 'ALTER FOREIGN TABLE', 'ALTER FUNCTION', 'ALTER POLICY', 'ALTER SCHEMA', 'ALTER TABLE', 'ALTER TYPE', 'ALTER VIEW', 'COMMENT', 'CREATE AGGREGATE', 'CREATE DOMAIN', 'CREATE EXTENSION', 'CREATE FOREIGN TABLE', 'CREATE FUNCTION', 'CREATE INDEX', 'CREATE POLICY', 'CREATE RULE', 'CREATE SCHEMA', 'CREATE TABLE', 'CREATE TABLE AS', 'CREATE VIEW', 'DROP AGGREGATE', 'DROP DOMAIN', 'DROP EXTENSION', 'DROP FOREIGN TABLE', 'DROP FUNCTION', 'DROP INDEX', 'DROP OWNED', 'DROP POLICY', 'DROP RULE', 'DROP SCHEMA', 'DROP TABLE', 'DROP TYPE', 'DROP VIEW', 'GRANT', 'REVOKE', 'SELECT INTO')
   EXECUTE FUNCTION postgraphile_watch.notify_watchers_ddl();


--
-- Name: postgraphile_watch_drop; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER postgraphile_watch_drop ON sql_drop
   EXECUTE FUNCTION postgraphile_watch.notify_watchers_drop();


--
-- PostgreSQL database dump complete
--

