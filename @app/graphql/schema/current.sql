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
-- Name: procrastinate; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA procrastinate;


--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

-- *not* creating schema, since initdb creates it


--
-- Name: sqitch; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA sqitch;


--
-- Name: SCHEMA sqitch; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA sqitch IS 'Sqitch database deployment metadata v1.1.';


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
-- Name: ability; Type: TYPE; Schema: app_public; Owner: -
--

CREATE TYPE app_public.ability AS ENUM (
    'view',
    'create',
    'create__space',
    'create__message',
    'create__file',
    'update',
    'update__space',
    'update__message',
    'update__file',
    'delete',
    'delete__space',
    'delete__message',
    'delete__file',
    'submit',
    'submit__message',
    'submit__file',
    'accept',
    'accept__message',
    'accept__file',
    'grant',
    'grant__ability',
    'manage'
);


--
-- Name: procrastinate_job_event_type; Type: TYPE; Schema: procrastinate; Owner: -
--

CREATE TYPE procrastinate.procrastinate_job_event_type AS ENUM (
    'deferred',
    'started',
    'deferred_for_retry',
    'failed',
    'succeeded',
    'cancelled',
    'scheduled'
);


--
-- Name: procrastinate_job_status; Type: TYPE; Schema: procrastinate; Owner: -
--

CREATE TYPE procrastinate.procrastinate_job_status AS ENUM (
    'todo',
    'doing',
    'succeeded',
    'failed'
);


--
-- Name: auto_subscribe_after_space_creation(); Type: FUNCTION; Schema: app_hidden; Owner: -
--

CREATE FUNCTION app_hidden.auto_subscribe_after_space_creation() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
declare
  my_user_id uuid := app_public.current_user_id();
  abilities_for_space_creators app_public.ability[];
begin
  select space_creator_abilities into abilities_for_space_creators
    from app_public.organizations
    where id = new.organization_id;

  if 
    my_user_id is not null 
    and array_length(abilities_for_space_creators, 1) > 0 
  then
    insert into app_public.space_subscriptions (space_id, subscriber_id, abilities)
      values (new.id, my_user_id, abilities_for_space_creators);
  end if;
  return new;
end
$$;


--
-- Name: rebase_message_revisions_before_deletion(); Type: FUNCTION; Schema: app_hidden; Owner: -
--

CREATE FUNCTION app_hidden.rebase_message_revisions_before_deletion() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
begin
  update app_public.message_revisions
    set parent_revision_id = old.parent_revision_id
    where 
      id = old.id 
      and parent_revision_id = old.revision_id;
  return old;
end
$$;


--
-- Name: refresh_user_abilities_per_organization_on_update(); Type: FUNCTION; Schema: app_hidden; Owner: -
--

CREATE FUNCTION app_hidden.refresh_user_abilities_per_organization_on_update() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
begin
  with new_abilities_per_user_and_organization as (
    select
      m.user_id,
      m.organization_id,
      array(
        select distinct e
        from unnest(
          case 
          when m.is_owner then 
            NEW.owner_abilities || NEW.member_abilities || m.abilities
          else 
            NEW.member_abilities || m.abilities
          end
        ) as _(e)
        order by e
      ) as abilities
    from app_public.organization_memberships as m
    where m.organization_id = NEW.id
  )
  merge into app_hidden.user_abilities_per_organization as t
  using new_abilities_per_user_and_organization as s 
    on (t.organization_id = s.organization_id and t."user_id" = s."user_id")
  when matched and s.abilities is distinct from t.abilities then
    update set abilities = s.abilities;

  return new;
end
$$;


--
-- Name: refresh_user_abilities_per_organization_when_memberships_change(); Type: FUNCTION; Schema: app_hidden; Owner: -
--

CREATE FUNCTION app_hidden.refresh_user_abilities_per_organization_when_memberships_change() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
begin
  -- Step 1: Delete old memberships, if not updated.
  -- Afterwards, there are no more rows of old_memberships, 
  -- that are not also included in new_memberships.
  -- That is important for step 2.
  if tg_op = 'UPDATE' then
    delete from app_public.organization_memberships
    where (organization_id, "user_id") in (
      select organization_id, "user_id" from old_memberships
      except 
      select organization_id, "user_id" from new_memberships
    );
  end if;

  -- Step 2: Update or create memberships.
  with new_abilities_per_user_and_organization as (
    select
      m.user_id,
      m.organization_id,
      array(
        select distinct e
        from unnest(
          case 
          when m.is_owner then 
            o.owner_abilities || o.member_abilities || m.abilities
          else 
            o.member_abilities || m.abilities
          end
        ) as _(e)
        order by e
      ) as abilities
    from new_memberships as m
    join app_public.organizations as o on (m.organization_id = o.id)
  )
  merge into app_hidden.user_abilities_per_organization as t
  using new_abilities_per_user_and_organization as s 
    on (t.organization_id = s.organization_id and t."user_id" = s."user_id")
  when matched and s.abilities is distinct from t.abilities then
    update set abilities = s.abilities
  when not matched then
    insert ("user_id", organization_id, abilities) values (s."user_id", s.organization_id, s.abilities);
  
  return new;
end
$$;


--
-- Name: refresh_user_abilities_per_space_when_memberships_change(); Type: FUNCTION; Schema: app_hidden; Owner: -
--

CREATE FUNCTION app_hidden.refresh_user_abilities_per_space_when_memberships_change() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
declare
  affected_user_ids uuid[] := '{}';
begin
  if tg_op in ('DELETE', 'UPDATE') then
    affected_user_ids := (select array(select "user_id" from old_memberships) || affected_user_ids);
  end if;

  if tg_op in ('INSERT', 'UPDATE') then
    affected_user_ids := (select array(select "user_id" from new_memberships) || affected_user_ids);
  end if;

  with new_abilities_per_user_and_space as (
    select
      sub.subscriber_id as "user_id",
      sub.space_id,
      array(
        select unnest(sub.abilities)
        union 
        select unnest(oa.abilities)
      ) as abilities,
      array(
        select unnest(sub.abilities) where '{manage,grant,grant__ability}' && sub.abilities
        union 
        select unnest(oa.abilities) where '{manage,grant,grant__ability}' && oa.abilities
      ) as abilities_with_grant_option
    from app_public.space_subscriptions as sub
    join app_public.spaces as s on (sub.space_id = s.id)
    -- Organization memberships are optional. For members, abilities propagate to the spaces of an organization.
    left join app_hidden.user_abilities_per_organization as oa on (s.organization_id = oa.organization_id and sub.subscriber_id = oa.user_id)
    where sub.subscriber_id = any (affected_user_ids)
  )
  merge into app_hidden.user_abilities_per_space as t
  using new_abilities_per_user_and_space as s 
    on (t.space_id = s.space_id and t."user_id" = s."user_id")
  when matched and s.abilities is distinct from t.abilities then
    update set abilities = s.abilities, abilities_with_grant_option = s.abilities_with_grant_option
  when not matched then
    insert ("user_id", space_id, abilities, abilities_with_grant_option) values (s."user_id", s.space_id, s.abilities, s.abilities_with_grant_option);

  if tg_op = 'DELETE' then
    return old;
  else
    return new;
  end if;
end
$$;


--
-- Name: refresh_user_abilities_per_space_when_subscriptions_change(); Type: FUNCTION; Schema: app_hidden; Owner: -
--

CREATE FUNCTION app_hidden.refresh_user_abilities_per_space_when_subscriptions_change() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
begin
  -- Step 1: Delete old subscriptions, if not updated.
  -- Afterwards, there are no more rows of old_subscriptions, 
  -- that are not also included in new_subscriptions.
  -- That is important for step 2.
  if tg_op = 'UPDATE' then
    delete from app_public.space_subscriptions
    where (space_id, subscriber_id) in (
      select space_id, subscriber_id from old_subscriptions
      except 
      select space_id, subscriber_id from new_subscriptions
    );
  end if;

  -- Step 2: Update or create memberships.
  with new_abilities_per_user_and_space as (
    select
      sub.subscriber_id as "user_id",
      sub.space_id,
      array(
        select unnest(sub.abilities)
        union 
        select unnest(oa.abilities)
      ) as abilities,
      array(
        select unnest(sub.abilities) 
        where 
          '{manage,grant,grant__ability}' && sub.abilities
          or '{manage,grant,grant__ability}' && oa.abilities
        union 
        select unnest(oa.abilities) where '{manage,grant,grant__ability}' && oa.abilities
      ) as abilities_with_grant_option
    from new_subscriptions as sub
    join app_public.spaces as s on (sub.space_id = s.id)
    -- Organization memberships are optional. For members, abilities propagate to the spaces of an organization.
    left join app_hidden.user_abilities_per_organization as oa on (s.organization_id = oa.organization_id and sub.subscriber_id = oa.user_id)
  )
  merge into app_hidden.user_abilities_per_space as t
  using new_abilities_per_user_and_space as s 
    on (t.space_id = s.space_id and t."user_id" = s."user_id")
  when matched and s.abilities is distinct from t.abilities then
    update set abilities = s.abilities, abilities_with_grant_option = s.abilities_with_grant_option
  when not matched then
    insert ("user_id", space_id, abilities, abilities_with_grant_option) values (s."user_id", s.space_id, s.abilities, s.abilities_with_grant_option);
  
  return new;
end
$$;


--
-- Name: restrict_ability_updates_on_space_subscriptions(); Type: FUNCTION; Schema: app_hidden; Owner: -
--

CREATE FUNCTION app_hidden.restrict_ability_updates_on_space_subscriptions() RETURNS trigger
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $_$
declare
  my app_hidden.user_abilities_per_space;
  current_space app_public.spaces;
  added_abilities app_public.ability[] := array(
    select unnest(NEW.abilities) 
    except 
    select unnest(OLD.abilities)
  );
  categories_of_added_abilities app_public.ability[] := array(
    select distinct regexp_replace(
      unnest(added_abilities)::text, 
      '__.*$', 
      ''
    )::app_public.ability
  );
begin
  -- OK: New abilities are a subset of the old ones.
  if 
    new.space_id = old.space_id
    and new.subscriber_id = old.subscriber_id
    and (
      new.abilities is null 
      or new.abilities <@ OLD.abilities 
      or categories_of_added_abilities <@ OLD.abilities
    ) 
  then
    return new;
  end if;

  -- Fetch space
  select * into current_space 
  from app_public.spaces 
  where id = new.space_id;

  -- Fetch my abilities in this space.
  select * into my
  from app_hidden.user_abilities_per_space
  where 
    space_id = new.space_id
    and "user_id"= app_public.current_user_id();

  -- Handle my own subscriptions.
  if new.subscriber_id = app_public.current_user_id() then
    -- Right here, new abilities must be a superset of old abilities.
    -- (Otherwise, this function would already have returned.)
    -- Giving yourself abilities is only allowed if you already had the 'manage' ability.
    if not 'manage' = any (my.abilities) then
      raise exception 'You can''t give yourself any new abilities.' using errcode = 'DNIED';
    end if;
  -- Handle subscriptions of others.
  else
    -- Verify that I am allowed to grant the added abilities.
    if not (
      added_abilities <@ my.abilities_with_grant_option
      or categories_of_added_abilities <@ my.abilities_with_grant_option
    ) then
      raise exception 'You are not allowed to grant these abilities.' using errcode = 'DNIED';
    end if;
  end if;
  
  return new;
end
$_$;


--
-- Name: update_active_or_current_message_revision(); Type: FUNCTION; Schema: app_hidden; Owner: -
--

CREATE FUNCTION app_hidden.update_active_or_current_message_revision() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  old_revision app_public.message_revisions;
  can_still_be_updated boolean;
begin
  if not (old.subject, old.body) is distinct from (new.subject, new.body) then
    return old;
  end if;

  -- Fetch old revision.
  select * into strict old_revision 
    from app_public.message_revisions 
    where id = old.id and revision_id = old.revision_id
    for update;

  -- An existing revision can still be updated, …
  can_still_be_updated := (
    -- … by the same author,
    old_revision.editor_id = app_public.current_user_id()
    -- … if the revision still is active.
    and (old_revision.id, old_revision.revision_id) in (
      select id, revision_id
      from app_public.active_message_revisions
    )
  );

  -- Perform an update, if still possible.
  if can_still_be_updated 
  then
    update app_public.message_revisions as r
    set 
      "subject" = new."subject",
      body = new.body
    where 
      r.id = old_revision.id
      and r.revision_id = old_revision.revision_id
    returning * into strict new;
  
  -- If no longer possible, add another revision istead.
  else
    insert into app_public.message_revisions 
      (id, parent_revision_id, "subject", body)
      values (old.id, old.revision_id, new.subject, new.body)
      returning * into strict new;
  end if;
  
  -- Return 
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
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    member_abilities app_public.ability[] DEFAULT '{create__message,update__message,submit__message}'::app_public.ability[] NOT NULL,
    owner_abilities app_public.ability[] DEFAULT '{manage}'::app_public.ability[] NOT NULL,
    space_creator_abilities app_public.ability[] DEFAULT '{manage}'::app_public.ability[] NOT NULL
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
-- Name: current_user_first_member_organization_id(); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.current_user_first_member_organization_id() RETURNS uuid
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
  select organization_id 
    from app_public.organization_memberships
    where user_id = app_public.current_user_id()
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
-- Name: my_organization_ids(app_public.ability[], app_public.ability[]); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.my_organization_ids(with_any_abilities app_public.ability[] DEFAULT '{view,manage}'::app_public.ability[], with_all_abilities app_public.ability[] DEFAULT '{}'::app_public.ability[]) RETURNS SETOF uuid
    LANGUAGE sql STABLE SECURITY DEFINER ROWS 30 PARALLEL SAFE
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
select organization_id
from app_hidden.user_abilities_per_organization
where
  "user_id" = app_public.current_user_id()
  and with_any_abilities && abilities
  and with_all_abilities <@ abilities
$$;


--
-- Name: my_space_ids(app_public.ability[], app_public.ability[]); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.my_space_ids(with_any_abilities app_public.ability[] DEFAULT '{view,manage}'::app_public.ability[], with_all_abilities app_public.ability[] DEFAULT '{}'::app_public.ability[]) RETURNS SETOF uuid
    LANGUAGE sql STABLE SECURITY DEFINER ROWS 30 PARALLEL SAFE
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
  select space_id
  from app_hidden.user_abilities_per_space
  where 
    "user_id" = app_public.current_user_id()
    and with_any_abilities && abilities
    and with_all_abilities <@ abilities
$$;


--
-- Name: my_space_subscription_ids(); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.my_space_subscription_ids() RETURNS SETOF uuid
    LANGUAGE sql STABLE SECURITY DEFINER ROWS 30 PARALLEL SAFE
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
  select id 
  from app_public.space_subscriptions
  where subscriber_id = app_public.current_user_id()
$$;


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
-- Name: procrastinate_defer_job(character varying, character varying, text, text, jsonb, timestamp with time zone); Type: FUNCTION; Schema: procrastinate; Owner: -
--

CREATE FUNCTION procrastinate.procrastinate_defer_job(queue_name character varying, task_name character varying, lock text, queueing_lock text, args jsonb, scheduled_at timestamp with time zone) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
	job_id bigint;
BEGIN
    INSERT INTO procrastinate_jobs (queue_name, task_name, lock, queueing_lock, args, scheduled_at)
    VALUES (queue_name, task_name, lock, queueing_lock, args, scheduled_at)
    RETURNING id INTO job_id;

    RETURN job_id;
END;
$$;


--
-- Name: procrastinate_defer_periodic_job(character varying, character varying, character varying, character varying, bigint); Type: FUNCTION; Schema: procrastinate; Owner: -
--

CREATE FUNCTION procrastinate.procrastinate_defer_periodic_job(_queue_name character varying, _lock character varying, _queueing_lock character varying, _task_name character varying, _defer_timestamp bigint) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
	_job_id bigint;
	_defer_id bigint;
BEGIN

    INSERT
        INTO procrastinate_periodic_defers (task_name, queue_name, defer_timestamp)
        VALUES (_task_name, _queue_name, _defer_timestamp)
        ON CONFLICT DO NOTHING
        RETURNING id into _defer_id;

    IF _defer_id IS NULL THEN
        RETURN NULL;
    END IF;

    UPDATE procrastinate_periodic_defers
        SET job_id = procrastinate_defer_job(
                _queue_name,
                _task_name,
                _lock,
                _queueing_lock,
                ('{"timestamp": ' || _defer_timestamp || '}')::jsonb,
                NULL
            )
        WHERE id = _defer_id
        RETURNING job_id INTO _job_id;

    DELETE
        FROM procrastinate_periodic_defers
        USING (
            SELECT id
            FROM procrastinate_periodic_defers
            WHERE procrastinate_periodic_defers.task_name = _task_name
            AND procrastinate_periodic_defers.queue_name = _queue_name
            AND procrastinate_periodic_defers.defer_timestamp < _defer_timestamp
            ORDER BY id
            FOR UPDATE
        ) to_delete
        WHERE procrastinate_periodic_defers.id = to_delete.id;

    RETURN _job_id;
END;
$$;


--
-- Name: procrastinate_defer_periodic_job(character varying, character varying, character varying, character varying, character varying, bigint, jsonb); Type: FUNCTION; Schema: procrastinate; Owner: -
--

CREATE FUNCTION procrastinate.procrastinate_defer_periodic_job(_queue_name character varying, _lock character varying, _queueing_lock character varying, _task_name character varying, _periodic_id character varying, _defer_timestamp bigint, _args jsonb) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
	_job_id bigint;
	_defer_id bigint;
BEGIN

    INSERT
        INTO procrastinate_periodic_defers (task_name, periodic_id, defer_timestamp)
        VALUES (_task_name, _periodic_id, _defer_timestamp)
        ON CONFLICT DO NOTHING
        RETURNING id into _defer_id;

    IF _defer_id IS NULL THEN
        RETURN NULL;
    END IF;

    UPDATE procrastinate_periodic_defers
        SET job_id = procrastinate_defer_job(
                _queue_name,
                _task_name,
                _lock,
                _queueing_lock,
                _args,
                NULL
            )
        WHERE id = _defer_id
        RETURNING job_id INTO _job_id;

    DELETE
        FROM procrastinate_periodic_defers
        USING (
            SELECT id
            FROM procrastinate_periodic_defers
            WHERE procrastinate_periodic_defers.task_name = _task_name
            AND procrastinate_periodic_defers.periodic_id = _periodic_id
            AND procrastinate_periodic_defers.defer_timestamp < _defer_timestamp
            ORDER BY id
            FOR UPDATE
        ) to_delete
        WHERE procrastinate_periodic_defers.id = to_delete.id;

    RETURN _job_id;
END;
$$;


--
-- Name: procrastinate_jobs; Type: TABLE; Schema: procrastinate; Owner: -
--

CREATE TABLE procrastinate.procrastinate_jobs (
    id bigint NOT NULL,
    queue_name character varying(128) NOT NULL,
    task_name character varying(128) NOT NULL,
    lock text,
    queueing_lock text,
    args jsonb DEFAULT '{}'::jsonb NOT NULL,
    status procrastinate.procrastinate_job_status DEFAULT 'todo'::procrastinate.procrastinate_job_status NOT NULL,
    scheduled_at timestamp with time zone,
    attempts integer DEFAULT 0 NOT NULL
);


--
-- Name: procrastinate_fetch_job(character varying[]); Type: FUNCTION; Schema: procrastinate; Owner: -
--

CREATE FUNCTION procrastinate.procrastinate_fetch_job(target_queue_names character varying[]) RETURNS procrastinate.procrastinate_jobs
    LANGUAGE plpgsql
    AS $$
DECLARE
	found_jobs procrastinate_jobs;
BEGIN
    WITH candidate AS (
        SELECT jobs.*
            FROM procrastinate_jobs AS jobs
            WHERE
                -- reject the job if its lock has earlier jobs
                NOT EXISTS (
                    SELECT 1
                        FROM procrastinate_jobs AS earlier_jobs
                        WHERE
                            jobs.lock IS NOT NULL
                            AND earlier_jobs.lock = jobs.lock
                            AND earlier_jobs.status IN ('todo', 'doing')
                            AND earlier_jobs.id < jobs.id)
                AND jobs.status = 'todo'
                AND (target_queue_names IS NULL OR jobs.queue_name = ANY( target_queue_names ))
                AND (jobs.scheduled_at IS NULL OR jobs.scheduled_at <= now())
            ORDER BY jobs.id ASC LIMIT 1
            FOR UPDATE OF jobs SKIP LOCKED
    )
    UPDATE procrastinate_jobs
        SET status = 'doing'
        FROM candidate
        WHERE procrastinate_jobs.id = candidate.id
        RETURNING procrastinate_jobs.* INTO found_jobs;

	RETURN found_jobs;
END;
$$;


--
-- Name: procrastinate_finish_job(integer, procrastinate.procrastinate_job_status); Type: FUNCTION; Schema: procrastinate; Owner: -
--

CREATE FUNCTION procrastinate.procrastinate_finish_job(job_id integer, end_status procrastinate.procrastinate_job_status) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE procrastinate_jobs
    SET status = end_status,
        attempts = attempts + 1
    WHERE id = job_id;
END;
$$;


--
-- Name: procrastinate_finish_job(integer, procrastinate.procrastinate_job_status, timestamp with time zone); Type: FUNCTION; Schema: procrastinate; Owner: -
--

CREATE FUNCTION procrastinate.procrastinate_finish_job(job_id integer, end_status procrastinate.procrastinate_job_status, next_scheduled_at timestamp with time zone) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE procrastinate_jobs
    SET status = end_status,
        attempts = attempts + 1,
        scheduled_at = COALESCE(next_scheduled_at, scheduled_at)
    WHERE id = job_id;
END;
$$;


--
-- Name: procrastinate_finish_job(integer, procrastinate.procrastinate_job_status, timestamp with time zone, boolean); Type: FUNCTION; Schema: procrastinate; Owner: -
--

CREATE FUNCTION procrastinate.procrastinate_finish_job(job_id integer, end_status procrastinate.procrastinate_job_status, next_scheduled_at timestamp with time zone, delete_job boolean) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    _job_id bigint;
BEGIN
    IF end_status NOT IN ('succeeded', 'failed') THEN
        RAISE 'End status should be either "succeeded" or "failed" (job id: %)', job_id;
    END IF;
    IF delete_job THEN
        DELETE FROM procrastinate_jobs
        WHERE id = job_id AND status IN ('todo', 'doing')
        RETURNING id INTO _job_id;
    ELSE
        UPDATE procrastinate_jobs
        SET status = end_status,
            attempts =
                CASE
                    WHEN status = 'doing' THEN attempts + 1
                    ELSE attempts
                END
        WHERE id = job_id AND status IN ('todo', 'doing')
        RETURNING id INTO _job_id;
    END IF;
    IF _job_id IS NULL THEN
        RAISE 'Job was not found or not in "doing" or "todo" status (job id: %)', job_id;
    END IF;
END;
$$;


--
-- Name: procrastinate_notify_queue(); Type: FUNCTION; Schema: procrastinate; Owner: -
--

CREATE FUNCTION procrastinate.procrastinate_notify_queue() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	PERFORM pg_notify('procrastinate_queue#' || NEW.queue_name, NEW.task_name);
	PERFORM pg_notify('procrastinate_any_queue', NEW.task_name);
	RETURN NEW;
END;
$$;


--
-- Name: procrastinate_retry_job(integer, timestamp with time zone); Type: FUNCTION; Schema: procrastinate; Owner: -
--

CREATE FUNCTION procrastinate.procrastinate_retry_job(job_id integer, retry_at timestamp with time zone) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    _job_id bigint;
BEGIN
    UPDATE procrastinate_jobs
    SET status = 'todo',
        attempts = attempts + 1,
        scheduled_at = retry_at
    WHERE id = job_id AND status = 'doing'
    RETURNING id INTO _job_id;
    IF _job_id IS NULL THEN
        RAISE 'Job was not found or not in "doing" status (job id: %)', job_id;
    END IF;
END;
$$;


--
-- Name: procrastinate_trigger_scheduled_events_procedure(); Type: FUNCTION; Schema: procrastinate; Owner: -
--

CREATE FUNCTION procrastinate.procrastinate_trigger_scheduled_events_procedure() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO procrastinate_events(job_id, type, at)
        VALUES (NEW.id, 'scheduled'::procrastinate_job_event_type, NEW.scheduled_at);

	RETURN NEW;
END;
$$;


--
-- Name: procrastinate_trigger_status_events_procedure_insert(); Type: FUNCTION; Schema: procrastinate; Owner: -
--

CREATE FUNCTION procrastinate.procrastinate_trigger_status_events_procedure_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO procrastinate_events(job_id, type)
        VALUES (NEW.id, 'deferred'::procrastinate_job_event_type);
	RETURN NEW;
END;
$$;


--
-- Name: procrastinate_trigger_status_events_procedure_update(); Type: FUNCTION; Schema: procrastinate; Owner: -
--

CREATE FUNCTION procrastinate.procrastinate_trigger_status_events_procedure_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    WITH t AS (
        SELECT CASE
            WHEN OLD.status = 'todo'::procrastinate_job_status
                AND NEW.status = 'doing'::procrastinate_job_status
                THEN 'started'::procrastinate_job_event_type
            WHEN OLD.status = 'doing'::procrastinate_job_status
                AND NEW.status = 'todo'::procrastinate_job_status
                THEN 'deferred_for_retry'::procrastinate_job_event_type
            WHEN OLD.status = 'doing'::procrastinate_job_status
                AND NEW.status = 'failed'::procrastinate_job_status
                THEN 'failed'::procrastinate_job_event_type
            WHEN OLD.status = 'doing'::procrastinate_job_status
                AND NEW.status = 'succeeded'::procrastinate_job_status
                THEN 'succeeded'::procrastinate_job_event_type
            WHEN OLD.status = 'todo'::procrastinate_job_status
                AND (
                    NEW.status = 'failed'::procrastinate_job_status
                    OR NEW.status = 'succeeded'::procrastinate_job_status
                )
                THEN 'cancelled'::procrastinate_job_event_type
            ELSE NULL
        END as event_type
    )
    INSERT INTO procrastinate_events(job_id, type)
        SELECT NEW.id, t.event_type
        FROM t
        WHERE t.event_type IS NOT NULL;
	RETURN NEW;
END;
$$;


--
-- Name: procrastinate_unlink_periodic_defers(); Type: FUNCTION; Schema: procrastinate; Owner: -
--

CREATE FUNCTION procrastinate.procrastinate_unlink_periodic_defers() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE procrastinate_periodic_defers
    SET job_id = NULL
    WHERE job_id = OLD.id;
    RETURN OLD;
END;
$$;


--
-- Name: text_array_to_string(text[], text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.text_array_to_string(text[], text) RETURNS text
    LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE
    AS $$array_to_text$$;


--
-- Name: user_abilities_per_organization; Type: TABLE; Schema: app_hidden; Owner: -
--

CREATE TABLE app_hidden.user_abilities_per_organization (
    user_id uuid,
    organization_id uuid,
    abilities app_public.ability[]
);


--
-- Name: user_abilities_per_space; Type: TABLE; Schema: app_hidden; Owner: -
--

CREATE TABLE app_hidden.user_abilities_per_space (
    user_id uuid,
    space_id uuid,
    abilities app_public.ability[],
    abilities_with_grant_option app_public.ability[]
);


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
-- Name: message_revisions; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.message_revisions (
    id uuid DEFAULT public.uuid_generate_v1mc() NOT NULL,
    revision_id uuid DEFAULT public.uuid_generate_v1mc() NOT NULL,
    parent_revision_id uuid,
    editor_id uuid DEFAULT app_public.current_user_id(),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    update_comment text,
    subject text,
    body jsonb
);


--
-- Name: active_message_revisions; Type: VIEW; Schema: app_public; Owner: -
--

CREATE VIEW app_public.active_message_revisions WITH (security_barrier='true', security_invoker='true') AS
 SELECT id,
    revision_id,
    parent_revision_id,
    editor_id,
    created_at,
    updated_at,
    update_comment,
    subject,
    body
   FROM app_public.message_revisions leafs
  WHERE (NOT (EXISTS ( SELECT
           FROM app_public.message_revisions children
          WHERE (leafs.revision_id = children.parent_revision_id))))
  WITH CASCADED CHECK OPTION;


--
-- Name: VIEW active_message_revisions; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON VIEW app_public.active_message_revisions IS '
  @primaryKey id,revision_id
  ';


--
-- Name: current_message_revisions; Type: VIEW; Schema: app_public; Owner: -
--

CREATE VIEW app_public.current_message_revisions WITH (security_barrier='true', security_invoker='true') AS
 SELECT id,
    revision_id,
    parent_revision_id,
    editor_id,
    created_at,
    updated_at,
    update_comment,
    subject,
    body
   FROM app_public.message_revisions latest
  WHERE (NOT (EXISTS ( SELECT
           FROM app_public.message_revisions even_later
          WHERE ((even_later.id = latest.id) AND (even_later.updated_at > latest.updated_at)))))
  WITH CASCADED CHECK OPTION;


--
-- Name: VIEW current_message_revisions; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON VIEW app_public.current_message_revisions IS '
  @primaryKey id
  ';


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
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    abilities app_public.ability[]
);


--
-- Name: space_items; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.space_items (
    id uuid DEFAULT public.uuid_generate_v1mc() NOT NULL,
    space_id uuid NOT NULL,
    editor_id uuid DEFAULT app_public.current_user_id(),
    message_id uuid NOT NULL,
    revision_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: space_subscriptions; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.space_subscriptions (
    id uuid DEFAULT public.uuid_generate_v1mc() NOT NULL,
    space_id uuid,
    subscriber_id uuid,
    abilities app_public.ability[] DEFAULT '{view}'::app_public.ability[] NOT NULL,
    is_receiving_notifications boolean DEFAULT false NOT NULL,
    last_visit_at timestamp with time zone,
    last_notification_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: spaces; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.spaces (
    id uuid DEFAULT public.uuid_generate_v1mc() NOT NULL,
    organization_id uuid DEFAULT app_public.current_user_first_member_organization_id() NOT NULL,
    creator_id uuid DEFAULT app_public.current_user_id(),
    name text NOT NULL,
    slug text NOT NULL,
    is_public boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT is_valid_slug CHECK ((slug ~ '^[a-zA-Z0-9_-]+$'::text))
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
-- Name: procrastinate_events; Type: TABLE; Schema: procrastinate; Owner: -
--

CREATE TABLE procrastinate.procrastinate_events (
    id bigint NOT NULL,
    job_id integer NOT NULL,
    type procrastinate.procrastinate_job_event_type,
    at timestamp with time zone DEFAULT now()
);


--
-- Name: procrastinate_events_id_seq; Type: SEQUENCE; Schema: procrastinate; Owner: -
--

CREATE SEQUENCE procrastinate.procrastinate_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: procrastinate_events_id_seq; Type: SEQUENCE OWNED BY; Schema: procrastinate; Owner: -
--

ALTER SEQUENCE procrastinate.procrastinate_events_id_seq OWNED BY procrastinate.procrastinate_events.id;


--
-- Name: procrastinate_jobs_id_seq; Type: SEQUENCE; Schema: procrastinate; Owner: -
--

CREATE SEQUENCE procrastinate.procrastinate_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: procrastinate_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: procrastinate; Owner: -
--

ALTER SEQUENCE procrastinate.procrastinate_jobs_id_seq OWNED BY procrastinate.procrastinate_jobs.id;


--
-- Name: procrastinate_periodic_defers; Type: TABLE; Schema: procrastinate; Owner: -
--

CREATE TABLE procrastinate.procrastinate_periodic_defers (
    id bigint NOT NULL,
    task_name character varying(128) NOT NULL,
    defer_timestamp bigint,
    job_id bigint,
    queue_name character varying(128),
    periodic_id character varying(128) DEFAULT ''::character varying NOT NULL
);


--
-- Name: procrastinate_periodic_defers_id_seq; Type: SEQUENCE; Schema: procrastinate; Owner: -
--

CREATE SEQUENCE procrastinate.procrastinate_periodic_defers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: procrastinate_periodic_defers_id_seq; Type: SEQUENCE OWNED BY; Schema: procrastinate; Owner: -
--

ALTER SEQUENCE procrastinate.procrastinate_periodic_defers_id_seq OWNED BY procrastinate.procrastinate_periodic_defers.id;


--
-- Name: changes; Type: TABLE; Schema: sqitch; Owner: -
--

CREATE TABLE sqitch.changes (
    change_id text NOT NULL,
    script_hash text,
    change text NOT NULL,
    project text NOT NULL,
    note text DEFAULT ''::text NOT NULL,
    committed_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    committer_name text NOT NULL,
    committer_email text NOT NULL,
    planned_at timestamp with time zone NOT NULL,
    planner_name text NOT NULL,
    planner_email text NOT NULL
);


--
-- Name: TABLE changes; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON TABLE sqitch.changes IS 'Tracks the changes currently deployed to the database.';


--
-- Name: COLUMN changes.change_id; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.changes.change_id IS 'Change primary key.';


--
-- Name: COLUMN changes.script_hash; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.changes.script_hash IS 'Deploy script SHA-1 hash.';


--
-- Name: COLUMN changes.change; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.changes.change IS 'Name of a deployed change.';


--
-- Name: COLUMN changes.project; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.changes.project IS 'Name of the Sqitch project to which the change belongs.';


--
-- Name: COLUMN changes.note; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.changes.note IS 'Description of the change.';


--
-- Name: COLUMN changes.committed_at; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.changes.committed_at IS 'Date the change was deployed.';


--
-- Name: COLUMN changes.committer_name; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.changes.committer_name IS 'Name of the user who deployed the change.';


--
-- Name: COLUMN changes.committer_email; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.changes.committer_email IS 'Email address of the user who deployed the change.';


--
-- Name: COLUMN changes.planned_at; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.changes.planned_at IS 'Date the change was added to the plan.';


--
-- Name: COLUMN changes.planner_name; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.changes.planner_name IS 'Name of the user who planed the change.';


--
-- Name: COLUMN changes.planner_email; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.changes.planner_email IS 'Email address of the user who planned the change.';


--
-- Name: dependencies; Type: TABLE; Schema: sqitch; Owner: -
--

CREATE TABLE sqitch.dependencies (
    change_id text NOT NULL,
    type text NOT NULL,
    dependency text NOT NULL,
    dependency_id text,
    CONSTRAINT dependencies_check CHECK ((((type = 'require'::text) AND (dependency_id IS NOT NULL)) OR ((type = 'conflict'::text) AND (dependency_id IS NULL))))
);


--
-- Name: TABLE dependencies; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON TABLE sqitch.dependencies IS 'Tracks the currently satisfied dependencies.';


--
-- Name: COLUMN dependencies.change_id; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.dependencies.change_id IS 'ID of the depending change.';


--
-- Name: COLUMN dependencies.type; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.dependencies.type IS 'Type of dependency.';


--
-- Name: COLUMN dependencies.dependency; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.dependencies.dependency IS 'Dependency name.';


--
-- Name: COLUMN dependencies.dependency_id; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.dependencies.dependency_id IS 'Change ID the dependency resolves to.';


--
-- Name: events; Type: TABLE; Schema: sqitch; Owner: -
--

CREATE TABLE sqitch.events (
    event text NOT NULL,
    change_id text NOT NULL,
    change text NOT NULL,
    project text NOT NULL,
    note text DEFAULT ''::text NOT NULL,
    requires text[] DEFAULT '{}'::text[] NOT NULL,
    conflicts text[] DEFAULT '{}'::text[] NOT NULL,
    tags text[] DEFAULT '{}'::text[] NOT NULL,
    committed_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    committer_name text NOT NULL,
    committer_email text NOT NULL,
    planned_at timestamp with time zone NOT NULL,
    planner_name text NOT NULL,
    planner_email text NOT NULL,
    CONSTRAINT events_event_check CHECK ((event = ANY (ARRAY['deploy'::text, 'revert'::text, 'fail'::text, 'merge'::text])))
);


--
-- Name: TABLE events; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON TABLE sqitch.events IS 'Contains full history of all deployment events.';


--
-- Name: COLUMN events.event; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.events.event IS 'Type of event.';


--
-- Name: COLUMN events.change_id; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.events.change_id IS 'Change ID.';


--
-- Name: COLUMN events.change; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.events.change IS 'Change name.';


--
-- Name: COLUMN events.project; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.events.project IS 'Name of the Sqitch project to which the change belongs.';


--
-- Name: COLUMN events.note; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.events.note IS 'Description of the change.';


--
-- Name: COLUMN events.requires; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.events.requires IS 'Array of the names of required changes.';


--
-- Name: COLUMN events.conflicts; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.events.conflicts IS 'Array of the names of conflicting changes.';


--
-- Name: COLUMN events.tags; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.events.tags IS 'Tags associated with the change.';


--
-- Name: COLUMN events.committed_at; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.events.committed_at IS 'Date the event was committed.';


--
-- Name: COLUMN events.committer_name; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.events.committer_name IS 'Name of the user who committed the event.';


--
-- Name: COLUMN events.committer_email; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.events.committer_email IS 'Email address of the user who committed the event.';


--
-- Name: COLUMN events.planned_at; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.events.planned_at IS 'Date the event was added to the plan.';


--
-- Name: COLUMN events.planner_name; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.events.planner_name IS 'Name of the user who planed the change.';


--
-- Name: COLUMN events.planner_email; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.events.planner_email IS 'Email address of the user who plan planned the change.';


--
-- Name: projects; Type: TABLE; Schema: sqitch; Owner: -
--

CREATE TABLE sqitch.projects (
    project text NOT NULL,
    uri text,
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    creator_name text NOT NULL,
    creator_email text NOT NULL
);


--
-- Name: TABLE projects; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON TABLE sqitch.projects IS 'Sqitch projects deployed to this database.';


--
-- Name: COLUMN projects.project; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.projects.project IS 'Unique Name of a project.';


--
-- Name: COLUMN projects.uri; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.projects.uri IS 'Optional project URI';


--
-- Name: COLUMN projects.created_at; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.projects.created_at IS 'Date the project was added to the database.';


--
-- Name: COLUMN projects.creator_name; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.projects.creator_name IS 'Name of the user who added the project.';


--
-- Name: COLUMN projects.creator_email; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.projects.creator_email IS 'Email address of the user who added the project.';


--
-- Name: releases; Type: TABLE; Schema: sqitch; Owner: -
--

CREATE TABLE sqitch.releases (
    version real NOT NULL,
    installed_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    installer_name text NOT NULL,
    installer_email text NOT NULL
);


--
-- Name: TABLE releases; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON TABLE sqitch.releases IS 'Sqitch registry releases.';


--
-- Name: COLUMN releases.version; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.releases.version IS 'Version of the Sqitch registry.';


--
-- Name: COLUMN releases.installed_at; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.releases.installed_at IS 'Date the registry release was installed.';


--
-- Name: COLUMN releases.installer_name; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.releases.installer_name IS 'Name of the user who installed the registry release.';


--
-- Name: COLUMN releases.installer_email; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.releases.installer_email IS 'Email address of the user who installed the registry release.';


--
-- Name: tags; Type: TABLE; Schema: sqitch; Owner: -
--

CREATE TABLE sqitch.tags (
    tag_id text NOT NULL,
    tag text NOT NULL,
    project text NOT NULL,
    change_id text NOT NULL,
    note text DEFAULT ''::text NOT NULL,
    committed_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    committer_name text NOT NULL,
    committer_email text NOT NULL,
    planned_at timestamp with time zone NOT NULL,
    planner_name text NOT NULL,
    planner_email text NOT NULL
);


--
-- Name: TABLE tags; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON TABLE sqitch.tags IS 'Tracks the tags currently applied to the database.';


--
-- Name: COLUMN tags.tag_id; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.tags.tag_id IS 'Tag primary key.';


--
-- Name: COLUMN tags.tag; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.tags.tag IS 'Project-unique tag name.';


--
-- Name: COLUMN tags.project; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.tags.project IS 'Name of the Sqitch project to which the tag belongs.';


--
-- Name: COLUMN tags.change_id; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.tags.change_id IS 'ID of last change deployed before the tag was applied.';


--
-- Name: COLUMN tags.note; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.tags.note IS 'Description of the tag.';


--
-- Name: COLUMN tags.committed_at; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.tags.committed_at IS 'Date the tag was applied to the database.';


--
-- Name: COLUMN tags.committer_name; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.tags.committer_name IS 'Name of the user who applied the tag.';


--
-- Name: COLUMN tags.committer_email; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.tags.committer_email IS 'Email address of the user who applied the tag.';


--
-- Name: COLUMN tags.planned_at; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.tags.planned_at IS 'Date the tag was added to the plan.';


--
-- Name: COLUMN tags.planner_name; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.tags.planner_name IS 'Name of the user who planed the tag.';


--
-- Name: COLUMN tags.planner_email; Type: COMMENT; Schema: sqitch; Owner: -
--

COMMENT ON COLUMN sqitch.tags.planner_email IS 'Email address of the user who planned the tag.';


--
-- Name: active_message_revisions id; Type: DEFAULT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.active_message_revisions ALTER COLUMN id SET DEFAULT public.uuid_generate_v1mc();


--
-- Name: active_message_revisions editor_id; Type: DEFAULT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.active_message_revisions ALTER COLUMN editor_id SET DEFAULT app_public.current_user_id();


--
-- Name: current_message_revisions id; Type: DEFAULT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.current_message_revisions ALTER COLUMN id SET DEFAULT public.uuid_generate_v1mc();


--
-- Name: current_message_revisions editor_id; Type: DEFAULT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.current_message_revisions ALTER COLUMN editor_id SET DEFAULT app_public.current_user_id();


--
-- Name: procrastinate_events id; Type: DEFAULT; Schema: procrastinate; Owner: -
--

ALTER TABLE ONLY procrastinate.procrastinate_events ALTER COLUMN id SET DEFAULT nextval('procrastinate.procrastinate_events_id_seq'::regclass);


--
-- Name: procrastinate_jobs id; Type: DEFAULT; Schema: procrastinate; Owner: -
--

ALTER TABLE ONLY procrastinate.procrastinate_jobs ALTER COLUMN id SET DEFAULT nextval('procrastinate.procrastinate_jobs_id_seq'::regclass);


--
-- Name: procrastinate_periodic_defers id; Type: DEFAULT; Schema: procrastinate; Owner: -
--

ALTER TABLE ONLY procrastinate.procrastinate_periodic_defers ALTER COLUMN id SET DEFAULT nextval('procrastinate.procrastinate_periodic_defers_id_seq'::regclass);


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
-- Name: message_revisions message_revisions_pk; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.message_revisions
    ADD CONSTRAINT message_revisions_pk PRIMARY KEY (id, revision_id);


--
-- Name: space_subscriptions one_subscription_per_space_and_user; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.space_subscriptions
    ADD CONSTRAINT one_subscription_per_space_and_user UNIQUE (subscriber_id, space_id);


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
-- Name: space_items space_items_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.space_items
    ADD CONSTRAINT space_items_pkey PRIMARY KEY (id);


--
-- Name: space_subscriptions space_subscriptions_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.space_subscriptions
    ADD CONSTRAINT space_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: spaces spaces_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.spaces
    ADD CONSTRAINT spaces_pkey PRIMARY KEY (id);


--
-- Name: user_authentications uniq_user_authentications; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.user_authentications
    ADD CONSTRAINT uniq_user_authentications UNIQUE (service, identifier);


--
-- Name: spaces unique_slug_per_organization; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.spaces
    ADD CONSTRAINT unique_slug_per_organization UNIQUE NULLS NOT DISTINCT (organization_id, slug);


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
-- Name: procrastinate_events procrastinate_events_pkey; Type: CONSTRAINT; Schema: procrastinate; Owner: -
--

ALTER TABLE ONLY procrastinate.procrastinate_events
    ADD CONSTRAINT procrastinate_events_pkey PRIMARY KEY (id);


--
-- Name: procrastinate_jobs procrastinate_jobs_pkey; Type: CONSTRAINT; Schema: procrastinate; Owner: -
--

ALTER TABLE ONLY procrastinate.procrastinate_jobs
    ADD CONSTRAINT procrastinate_jobs_pkey PRIMARY KEY (id);


--
-- Name: procrastinate_periodic_defers procrastinate_periodic_defers_pkey; Type: CONSTRAINT; Schema: procrastinate; Owner: -
--

ALTER TABLE ONLY procrastinate.procrastinate_periodic_defers
    ADD CONSTRAINT procrastinate_periodic_defers_pkey PRIMARY KEY (id);


--
-- Name: procrastinate_periodic_defers procrastinate_periodic_defers_unique; Type: CONSTRAINT; Schema: procrastinate; Owner: -
--

ALTER TABLE ONLY procrastinate.procrastinate_periodic_defers
    ADD CONSTRAINT procrastinate_periodic_defers_unique UNIQUE (task_name, periodic_id, defer_timestamp);


--
-- Name: changes changes_pkey; Type: CONSTRAINT; Schema: sqitch; Owner: -
--

ALTER TABLE ONLY sqitch.changes
    ADD CONSTRAINT changes_pkey PRIMARY KEY (change_id);


--
-- Name: changes changes_project_script_hash_key; Type: CONSTRAINT; Schema: sqitch; Owner: -
--

ALTER TABLE ONLY sqitch.changes
    ADD CONSTRAINT changes_project_script_hash_key UNIQUE (project, script_hash);


--
-- Name: dependencies dependencies_pkey; Type: CONSTRAINT; Schema: sqitch; Owner: -
--

ALTER TABLE ONLY sqitch.dependencies
    ADD CONSTRAINT dependencies_pkey PRIMARY KEY (change_id, dependency);


--
-- Name: events events_pkey; Type: CONSTRAINT; Schema: sqitch; Owner: -
--

ALTER TABLE ONLY sqitch.events
    ADD CONSTRAINT events_pkey PRIMARY KEY (change_id, committed_at);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: sqitch; Owner: -
--

ALTER TABLE ONLY sqitch.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (project);


--
-- Name: projects projects_uri_key; Type: CONSTRAINT; Schema: sqitch; Owner: -
--

ALTER TABLE ONLY sqitch.projects
    ADD CONSTRAINT projects_uri_key UNIQUE (uri);


--
-- Name: releases releases_pkey; Type: CONSTRAINT; Schema: sqitch; Owner: -
--

ALTER TABLE ONLY sqitch.releases
    ADD CONSTRAINT releases_pkey PRIMARY KEY (version);


--
-- Name: tags tags_pkey; Type: CONSTRAINT; Schema: sqitch; Owner: -
--

ALTER TABLE ONLY sqitch.tags
    ADD CONSTRAINT tags_pkey PRIMARY KEY (tag_id);


--
-- Name: tags tags_project_tag_key; Type: CONSTRAINT; Schema: sqitch; Owner: -
--

ALTER TABLE ONLY sqitch.tags
    ADD CONSTRAINT tags_project_tag_key UNIQUE (project, tag);


--
-- Name: user_abilities_per_organization_on_organization_id; Type: INDEX; Schema: app_hidden; Owner: -
--

CREATE INDEX user_abilities_per_organization_on_organization_id ON app_hidden.user_abilities_per_organization USING btree (organization_id);


--
-- Name: user_abilities_per_organization_on_organization_id_user_id; Type: INDEX; Schema: app_hidden; Owner: -
--

CREATE UNIQUE INDEX user_abilities_per_organization_on_organization_id_user_id ON app_hidden.user_abilities_per_organization USING btree (user_id, organization_id) INCLUDE (abilities);


--
-- Name: user_abilities_per_space_on_space_id; Type: INDEX; Schema: app_hidden; Owner: -
--

CREATE INDEX user_abilities_per_space_on_space_id ON app_hidden.user_abilities_per_space USING btree (space_id);


--
-- Name: user_abilities_per_space_on_user_id_space_id; Type: INDEX; Schema: app_hidden; Owner: -
--

CREATE UNIQUE INDEX user_abilities_per_space_on_user_id_space_id ON app_hidden.user_abilities_per_space USING btree (user_id, space_id) INCLUDE (abilities);


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
-- Name: message_revisions_on_created_at; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX message_revisions_on_created_at ON app_public.message_revisions USING brin (created_at);


--
-- Name: message_revisions_on_editor_id; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX message_revisions_on_editor_id ON app_public.message_revisions USING btree (editor_id);


--
-- Name: message_revisions_on_parent_revision_id; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX message_revisions_on_parent_revision_id ON app_public.message_revisions USING btree (parent_revision_id);


--
-- Name: message_revisions_on_revision_id; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX message_revisions_on_revision_id ON app_public.message_revisions USING btree (revision_id);


--
-- Name: message_revisions_on_updated_at; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX message_revisions_on_updated_at ON app_public.message_revisions USING brin (updated_at);


--
-- Name: organization_invitations_user_id_idx; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX organization_invitations_user_id_idx ON app_public.organization_invitations USING btree (user_id);


--
-- Name: organization_memberships_user_id_idx; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX organization_memberships_user_id_idx ON app_public.organization_memberships USING btree (user_id);


--
-- Name: space_items_on_created_at; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX space_items_on_created_at ON app_public.space_items USING brin (created_at);


--
-- Name: space_items_on_editor_id; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX space_items_on_editor_id ON app_public.space_items USING btree (editor_id);


--
-- Name: space_items_on_message_id_revision_id; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX space_items_on_message_id_revision_id ON app_public.space_items USING btree (message_id, revision_id);


--
-- Name: space_items_on_space_id; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX space_items_on_space_id ON app_public.space_items USING btree (space_id);


--
-- Name: space_items_on_updated_at; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX space_items_on_updated_at ON app_public.space_items USING btree (updated_at);


--
-- Name: spaces_on_created_at; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX spaces_on_created_at ON app_public.spaces USING btree (created_at);


--
-- Name: spaces_on_creator_id; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX spaces_on_creator_id ON app_public.spaces USING btree (creator_id);


--
-- Name: spaces_on_organization_id; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX spaces_on_organization_id ON app_public.spaces USING btree (organization_id);


--
-- Name: spaces_on_updated_at; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX spaces_on_updated_at ON app_public.spaces USING btree (updated_at);


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
-- Name: procrastinate_events_job_id_fkey; Type: INDEX; Schema: procrastinate; Owner: -
--

CREATE INDEX procrastinate_events_job_id_fkey ON procrastinate.procrastinate_events USING btree (job_id);


--
-- Name: procrastinate_jobs_id_lock_idx; Type: INDEX; Schema: procrastinate; Owner: -
--

CREATE INDEX procrastinate_jobs_id_lock_idx ON procrastinate.procrastinate_jobs USING btree (id, lock) WHERE (status = ANY (ARRAY['todo'::procrastinate.procrastinate_job_status, 'doing'::procrastinate.procrastinate_job_status]));


--
-- Name: procrastinate_jobs_lock_idx; Type: INDEX; Schema: procrastinate; Owner: -
--

CREATE UNIQUE INDEX procrastinate_jobs_lock_idx ON procrastinate.procrastinate_jobs USING btree (lock) WHERE (status = 'doing'::procrastinate.procrastinate_job_status);


--
-- Name: procrastinate_jobs_queue_name_idx; Type: INDEX; Schema: procrastinate; Owner: -
--

CREATE INDEX procrastinate_jobs_queue_name_idx ON procrastinate.procrastinate_jobs USING btree (queue_name);


--
-- Name: procrastinate_jobs_queueing_lock_idx; Type: INDEX; Schema: procrastinate; Owner: -
--

CREATE UNIQUE INDEX procrastinate_jobs_queueing_lock_idx ON procrastinate.procrastinate_jobs USING btree (queueing_lock) WHERE (status = 'todo'::procrastinate.procrastinate_job_status);


--
-- Name: procrastinate_periodic_defers_job_id_fkey; Type: INDEX; Schema: procrastinate; Owner: -
--

CREATE INDEX procrastinate_periodic_defers_job_id_fkey ON procrastinate.procrastinate_periodic_defers USING btree (job_id);


--
-- Name: user_abilities_per_organization _800_refresh_user_abilities_per_space_after_delete; Type: TRIGGER; Schema: app_hidden; Owner: -
--

CREATE TRIGGER _800_refresh_user_abilities_per_space_after_delete AFTER DELETE ON app_hidden.user_abilities_per_organization REFERENCING OLD TABLE AS old_memberships FOR EACH STATEMENT EXECUTE FUNCTION app_hidden.refresh_user_abilities_per_space_when_memberships_change();


--
-- Name: user_abilities_per_organization _800_refresh_user_abilities_per_space_after_insert; Type: TRIGGER; Schema: app_hidden; Owner: -
--

CREATE TRIGGER _800_refresh_user_abilities_per_space_after_insert AFTER INSERT ON app_hidden.user_abilities_per_organization REFERENCING NEW TABLE AS new_memberships FOR EACH STATEMENT EXECUTE FUNCTION app_hidden.refresh_user_abilities_per_space_when_memberships_change();


--
-- Name: user_abilities_per_organization _800_refresh_user_abilities_per_space_after_update; Type: TRIGGER; Schema: app_hidden; Owner: -
--

CREATE TRIGGER _800_refresh_user_abilities_per_space_after_update AFTER UPDATE ON app_hidden.user_abilities_per_organization REFERENCING OLD TABLE AS old_memberships NEW TABLE AS new_memberships FOR EACH STATEMENT EXECUTE FUNCTION app_hidden.refresh_user_abilities_per_space_when_memberships_change();


--
-- Name: message_revisions _100_timestamps; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _100_timestamps BEFORE INSERT OR UPDATE ON app_public.message_revisions FOR EACH ROW EXECUTE FUNCTION app_private.tg__timestamps();


--
-- Name: space_items _100_timestamps; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _100_timestamps BEFORE INSERT OR UPDATE ON app_public.space_items FOR EACH ROW EXECUTE FUNCTION app_private.tg__timestamps();


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
-- Name: message_revisions _200_rebase_message_revisions_before_deletion; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _200_rebase_message_revisions_before_deletion BEFORE DELETE ON app_public.message_revisions FOR EACH ROW EXECUTE FUNCTION app_hidden.rebase_message_revisions_before_deletion();


--
-- Name: space_subscriptions _200_timestamps; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _200_timestamps BEFORE INSERT OR UPDATE ON app_public.space_subscriptions FOR EACH ROW EXECUTE FUNCTION app_private.tg__timestamps();


--
-- Name: spaces _200_timestamps; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _200_timestamps BEFORE INSERT OR UPDATE ON app_public.spaces FOR EACH ROW EXECUTE FUNCTION app_private.tg__timestamps();


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
-- Name: spaces _500_auto_subscribe_after_space_creation; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _500_auto_subscribe_after_space_creation AFTER INSERT ON app_public.spaces FOR EACH ROW EXECUTE FUNCTION app_hidden.auto_subscribe_after_space_creation();


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
-- Name: active_message_revisions _500_update_active_message_revision; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _500_update_active_message_revision INSTEAD OF UPDATE ON app_public.active_message_revisions FOR EACH ROW EXECUTE FUNCTION app_hidden.update_active_or_current_message_revision();


--
-- Name: current_message_revisions _500_update_current_message_revision; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _500_update_current_message_revision INSTEAD OF UPDATE ON app_public.current_message_revisions FOR EACH ROW EXECUTE FUNCTION app_hidden.update_active_or_current_message_revision();


--
-- Name: user_emails _500_verify_account_on_verified; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _500_verify_account_on_verified AFTER INSERT OR UPDATE OF is_verified ON app_public.user_emails FOR EACH ROW WHEN ((new.is_verified IS TRUE)) EXECUTE FUNCTION app_public.tg_user_emails__verify_account_on_verified();


--
-- Name: organizations _800_refresh_user_abilities_per_organization; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _800_refresh_user_abilities_per_organization AFTER UPDATE OF owner_abilities, member_abilities ON app_public.organizations FOR EACH ROW EXECUTE FUNCTION app_hidden.refresh_user_abilities_per_organization_on_update();


--
-- Name: organization_memberships _800_refresh_user_abilities_per_organization_after_insert; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _800_refresh_user_abilities_per_organization_after_insert AFTER INSERT ON app_public.organization_memberships REFERENCING NEW TABLE AS new_memberships FOR EACH STATEMENT EXECUTE FUNCTION app_hidden.refresh_user_abilities_per_organization_when_memberships_change();


--
-- Name: organization_memberships _800_refresh_user_abilities_per_organization_after_update; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _800_refresh_user_abilities_per_organization_after_update AFTER UPDATE ON app_public.organization_memberships REFERENCING OLD TABLE AS old_memberships NEW TABLE AS new_memberships FOR EACH STATEMENT EXECUTE FUNCTION app_hidden.refresh_user_abilities_per_organization_when_memberships_change();


--
-- Name: space_subscriptions _800_refresh_user_abilities_per_space_after_insert; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _800_refresh_user_abilities_per_space_after_insert AFTER INSERT ON app_public.space_subscriptions REFERENCING NEW TABLE AS new_subscriptions FOR EACH STATEMENT EXECUTE FUNCTION app_hidden.refresh_user_abilities_per_space_when_subscriptions_change();


--
-- Name: space_subscriptions _800_refresh_user_abilities_per_space_after_update; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _800_refresh_user_abilities_per_space_after_update AFTER UPDATE ON app_public.space_subscriptions REFERENCING OLD TABLE AS old_subscriptions NEW TABLE AS new_subscriptions FOR EACH STATEMENT EXECUTE FUNCTION app_hidden.refresh_user_abilities_per_space_when_subscriptions_change();


--
-- Name: space_subscriptions _900_restrict_ability_updates; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _900_restrict_ability_updates BEFORE UPDATE ON app_public.space_subscriptions FOR EACH ROW WHEN ((old.abilities IS DISTINCT FROM new.abilities)) EXECUTE FUNCTION app_hidden.restrict_ability_updates_on_space_subscriptions();


--
-- Name: user_emails _900_send_verification_email; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _900_send_verification_email AFTER INSERT ON app_public.user_emails FOR EACH ROW WHEN ((new.is_verified IS FALSE)) EXECUTE FUNCTION app_private.tg__add_job('user_emails__send_verification');


--
-- Name: procrastinate_jobs procrastinate_jobs_notify_queue; Type: TRIGGER; Schema: procrastinate; Owner: -
--

CREATE TRIGGER procrastinate_jobs_notify_queue AFTER INSERT ON procrastinate.procrastinate_jobs FOR EACH ROW WHEN ((new.status = 'todo'::procrastinate.procrastinate_job_status)) EXECUTE FUNCTION procrastinate.procrastinate_notify_queue();


--
-- Name: procrastinate_jobs procrastinate_trigger_delete_jobs; Type: TRIGGER; Schema: procrastinate; Owner: -
--

CREATE TRIGGER procrastinate_trigger_delete_jobs BEFORE DELETE ON procrastinate.procrastinate_jobs FOR EACH ROW EXECUTE FUNCTION procrastinate.procrastinate_unlink_periodic_defers();


--
-- Name: procrastinate_jobs procrastinate_trigger_scheduled_events; Type: TRIGGER; Schema: procrastinate; Owner: -
--

CREATE TRIGGER procrastinate_trigger_scheduled_events AFTER INSERT OR UPDATE ON procrastinate.procrastinate_jobs FOR EACH ROW WHEN (((new.scheduled_at IS NOT NULL) AND (new.status = 'todo'::procrastinate.procrastinate_job_status))) EXECUTE FUNCTION procrastinate.procrastinate_trigger_scheduled_events_procedure();


--
-- Name: procrastinate_jobs procrastinate_trigger_status_events_insert; Type: TRIGGER; Schema: procrastinate; Owner: -
--

CREATE TRIGGER procrastinate_trigger_status_events_insert AFTER INSERT ON procrastinate.procrastinate_jobs FOR EACH ROW WHEN ((new.status = 'todo'::procrastinate.procrastinate_job_status)) EXECUTE FUNCTION procrastinate.procrastinate_trigger_status_events_procedure_insert();


--
-- Name: procrastinate_jobs procrastinate_trigger_status_events_update; Type: TRIGGER; Schema: procrastinate; Owner: -
--

CREATE TRIGGER procrastinate_trigger_status_events_update AFTER UPDATE OF status ON procrastinate.procrastinate_jobs FOR EACH ROW EXECUTE FUNCTION procrastinate.procrastinate_trigger_status_events_procedure_update();


--
-- Name: user_abilities_per_organization organization; Type: FK CONSTRAINT; Schema: app_hidden; Owner: -
--

ALTER TABLE ONLY app_hidden.user_abilities_per_organization
    ADD CONSTRAINT organization FOREIGN KEY (organization_id) REFERENCES app_public.organizations(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: user_abilities_per_organization organization_membership; Type: FK CONSTRAINT; Schema: app_hidden; Owner: -
--

ALTER TABLE ONLY app_hidden.user_abilities_per_organization
    ADD CONSTRAINT organization_membership FOREIGN KEY (organization_id, user_id) REFERENCES app_public.organization_memberships(organization_id, user_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: user_abilities_per_space space; Type: FK CONSTRAINT; Schema: app_hidden; Owner: -
--

ALTER TABLE ONLY app_hidden.user_abilities_per_space
    ADD CONSTRAINT space FOREIGN KEY (space_id) REFERENCES app_public.spaces(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: user_abilities_per_space space_subscription; Type: FK CONSTRAINT; Schema: app_hidden; Owner: -
--

ALTER TABLE ONLY app_hidden.user_abilities_per_space
    ADD CONSTRAINT space_subscription FOREIGN KEY (space_id, user_id) REFERENCES app_public.space_subscriptions(space_id, subscriber_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: user_abilities_per_organization user; Type: FK CONSTRAINT; Schema: app_hidden; Owner: -
--

ALTER TABLE ONLY app_hidden.user_abilities_per_organization
    ADD CONSTRAINT "user" FOREIGN KEY (user_id) REFERENCES app_public.users(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: user_abilities_per_space user; Type: FK CONSTRAINT; Schema: app_hidden; Owner: -
--

ALTER TABLE ONLY app_hidden.user_abilities_per_space
    ADD CONSTRAINT "user" FOREIGN KEY (user_id) REFERENCES app_public.users(id) ON UPDATE CASCADE ON DELETE CASCADE;


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
-- Name: spaces creator; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.spaces
    ADD CONSTRAINT creator FOREIGN KEY (creator_id) REFERENCES app_public.users(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: space_items creator; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.space_items
    ADD CONSTRAINT creator FOREIGN KEY (editor_id) REFERENCES app_public.users(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: message_revisions editor; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.message_revisions
    ADD CONSTRAINT editor FOREIGN KEY (editor_id) REFERENCES app_public.users(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: space_items message_revision; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.space_items
    ADD CONSTRAINT message_revision FOREIGN KEY (message_id, revision_id) REFERENCES app_public.message_revisions(id, revision_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: spaces organization; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.spaces
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
-- Name: message_revisions parent_revision; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.message_revisions
    ADD CONSTRAINT parent_revision FOREIGN KEY (id, parent_revision_id) REFERENCES app_public.message_revisions(id, revision_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT parent_revision ON message_revisions; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON CONSTRAINT parent_revision ON app_public.message_revisions IS '
  @fieldName parentRevision
  @foreignFieldName childRevisions
  ';


--
-- Name: space_subscriptions space; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.space_subscriptions
    ADD CONSTRAINT space FOREIGN KEY (space_id) REFERENCES app_public.spaces(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: CONSTRAINT space ON space_subscriptions; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON CONSTRAINT space ON app_public.space_subscriptions IS '@foreignFieldName subscriptions';


--
-- Name: space_items space; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.space_items
    ADD CONSTRAINT space FOREIGN KEY (space_id) REFERENCES app_public.spaces(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: CONSTRAINT space ON space_items; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON CONSTRAINT space ON app_public.space_items IS '@foreignFieldName items';


--
-- Name: space_subscriptions subscriber; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.space_subscriptions
    ADD CONSTRAINT subscriber FOREIGN KEY (subscriber_id) REFERENCES app_public.users(id) ON UPDATE CASCADE ON DELETE CASCADE;


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
-- Name: procrastinate_events procrastinate_events_job_id_fkey; Type: FK CONSTRAINT; Schema: procrastinate; Owner: -
--

ALTER TABLE ONLY procrastinate.procrastinate_events
    ADD CONSTRAINT procrastinate_events_job_id_fkey FOREIGN KEY (job_id) REFERENCES procrastinate.procrastinate_jobs(id) ON DELETE CASCADE;


--
-- Name: procrastinate_periodic_defers procrastinate_periodic_defers_job_id_fkey; Type: FK CONSTRAINT; Schema: procrastinate; Owner: -
--

ALTER TABLE ONLY procrastinate.procrastinate_periodic_defers
    ADD CONSTRAINT procrastinate_periodic_defers_job_id_fkey FOREIGN KEY (job_id) REFERENCES procrastinate.procrastinate_jobs(id);


--
-- Name: changes changes_project_fkey; Type: FK CONSTRAINT; Schema: sqitch; Owner: -
--

ALTER TABLE ONLY sqitch.changes
    ADD CONSTRAINT changes_project_fkey FOREIGN KEY (project) REFERENCES sqitch.projects(project) ON UPDATE CASCADE;


--
-- Name: dependencies dependencies_change_id_fkey; Type: FK CONSTRAINT; Schema: sqitch; Owner: -
--

ALTER TABLE ONLY sqitch.dependencies
    ADD CONSTRAINT dependencies_change_id_fkey FOREIGN KEY (change_id) REFERENCES sqitch.changes(change_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: dependencies dependencies_dependency_id_fkey; Type: FK CONSTRAINT; Schema: sqitch; Owner: -
--

ALTER TABLE ONLY sqitch.dependencies
    ADD CONSTRAINT dependencies_dependency_id_fkey FOREIGN KEY (dependency_id) REFERENCES sqitch.changes(change_id) ON UPDATE CASCADE;


--
-- Name: events events_project_fkey; Type: FK CONSTRAINT; Schema: sqitch; Owner: -
--

ALTER TABLE ONLY sqitch.events
    ADD CONSTRAINT events_project_fkey FOREIGN KEY (project) REFERENCES sqitch.projects(project) ON UPDATE CASCADE;


--
-- Name: tags tags_change_id_fkey; Type: FK CONSTRAINT; Schema: sqitch; Owner: -
--

ALTER TABLE ONLY sqitch.tags
    ADD CONSTRAINT tags_change_id_fkey FOREIGN KEY (change_id) REFERENCES sqitch.changes(change_id) ON UPDATE CASCADE;


--
-- Name: tags tags_project_fkey; Type: FK CONSTRAINT; Schema: sqitch; Owner: -
--

ALTER TABLE ONLY sqitch.tags
    ADD CONSTRAINT tags_project_fkey FOREIGN KEY (project) REFERENCES sqitch.projects(project) ON UPDATE CASCADE;


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
-- Name: spaces can_create_root_spaces_when_organization_abilities_match; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY can_create_root_spaces_when_organization_abilities_match ON app_public.spaces FOR INSERT TO null814_cms_app_users WITH CHECK ((EXISTS ( SELECT
   FROM app_hidden.user_abilities_per_organization
  WHERE ((user_abilities_per_organization.user_id = app_public.current_user_id()) AND (user_abilities_per_organization.organization_id IN ( SELECT app_public.current_user_member_organization_ids() AS current_user_member_organization_ids)) AND (user_abilities_per_organization.organization_id = spaces.organization_id) AND ('{create__space,create,manage}'::app_public.ability[] && user_abilities_per_organization.abilities)))));


--
-- Name: space_subscriptions can_delete_my_subscriptions; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY can_delete_my_subscriptions ON app_public.space_subscriptions FOR DELETE TO null814_cms_app_users USING ((id IN ( SELECT app_public.my_space_subscription_ids() AS my_space_subscription_ids)));


--
-- Name: space_subscriptions can_insert_own_subscriptions_if_space_is_public; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY can_insert_own_subscriptions_if_space_is_public ON app_public.space_subscriptions FOR INSERT TO null814_cms_app_users WITH CHECK (((subscriber_id = app_public.current_user_id()) AND ((abilities IS NULL) OR (abilities <@ '{view}'::app_public.ability[])) AND (space_id IN ( SELECT spaces.id
   FROM app_public.spaces
  WHERE spaces.is_public))));


--
-- Name: spaces can_manage_with_matching_abilities; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY can_manage_with_matching_abilities ON app_public.spaces TO null814_cms_app_users USING (((id IN ( SELECT app_public.my_space_ids(with_any_abilities => '{manage}'::app_public.ability[]) AS my_space_ids)) OR (organization_id IN ( SELECT app_public.my_organization_ids(with_any_abilities => '{manage}'::app_public.ability[]) AS my_organization_ids))));


--
-- Name: spaces can_select_if_newly_created; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY can_select_if_newly_created ON app_public.spaces FOR SELECT TO null814_cms_app_users USING ((created_at = CURRENT_TIMESTAMP));


--
-- Name: spaces can_select_if_public; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY can_select_if_public ON app_public.spaces FOR SELECT USING (is_public);


--
-- Name: spaces can_select_if_subscribed; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY can_select_if_subscribed ON app_public.spaces FOR SELECT TO null814_cms_app_users USING (((id IN ( SELECT app_public.my_space_ids(with_any_abilities => '{view,manage}'::app_public.ability[]) AS my_space_ids)) OR (organization_id IN ( SELECT app_public.my_organization_ids(with_any_abilities => '{view,manage}'::app_public.ability[]) AS my_organization_ids))));


--
-- Name: space_subscriptions can_select_my_subscriptions; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY can_select_my_subscriptions ON app_public.space_subscriptions FOR SELECT TO null814_cms_app_users USING ((id IN ( SELECT app_public.my_space_subscription_ids() AS my_space_subscription_ids)));


--
-- Name: space_subscriptions can_update_my_subscriptions; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY can_update_my_subscriptions ON app_public.space_subscriptions FOR UPDATE TO null814_cms_app_users USING ((id IN ( SELECT app_public.my_space_subscription_ids() AS my_space_subscription_ids)));


--
-- Name: message_revisions delete_mine; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY delete_mine ON app_public.message_revisions FOR DELETE TO null814_cms_app_users USING ((editor_id = app_public.current_user_id()));


--
-- Name: user_authentications delete_own; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY delete_own ON app_public.user_authentications FOR DELETE USING ((user_id = app_public.current_user_id()));


--
-- Name: user_emails delete_own; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY delete_own ON app_public.user_emails FOR DELETE USING ((user_id = app_public.current_user_id()));


--
-- Name: message_revisions insert_mine_if_active; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY insert_mine_if_active ON app_public.message_revisions FOR INSERT TO null814_cms_app_users WITH CHECK (((editor_id = app_public.current_user_id()) AND (NOT (EXISTS ( SELECT
   FROM app_public.message_revisions children
  WHERE (children.parent_revision_id = message_revisions.revision_id))))));


--
-- Name: user_emails insert_own; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY insert_own ON app_public.user_emails FOR INSERT WITH CHECK ((user_id = app_public.current_user_id()));


--
-- Name: message_revisions; Type: ROW SECURITY; Schema: app_public; Owner: -
--

ALTER TABLE app_public.message_revisions ENABLE ROW LEVEL SECURITY;

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
-- Name: users select_all; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY select_all ON app_public.users FOR SELECT USING (true);


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
-- Name: message_revisions select_mine; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY select_mine ON app_public.message_revisions FOR SELECT TO null814_cms_app_users USING ((editor_id = app_public.current_user_id()));


--
-- Name: space_items select_own; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY select_own ON app_public.space_items FOR SELECT TO null814_cms_app_users USING ((editor_id = app_public.current_user_id()));


--
-- Name: user_authentications select_own; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY select_own ON app_public.user_authentications FOR SELECT USING ((user_id = app_public.current_user_id()));


--
-- Name: user_emails select_own; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY select_own ON app_public.user_emails FOR SELECT USING ((user_id = app_public.current_user_id()));


--
-- Name: space_items; Type: ROW SECURITY; Schema: app_public; Owner: -
--

ALTER TABLE app_public.space_items ENABLE ROW LEVEL SECURITY;

--
-- Name: space_subscriptions; Type: ROW SECURITY; Schema: app_public; Owner: -
--

ALTER TABLE app_public.space_subscriptions ENABLE ROW LEVEL SECURITY;

--
-- Name: spaces; Type: ROW SECURITY; Schema: app_public; Owner: -
--

ALTER TABLE app_public.spaces ENABLE ROW LEVEL SECURITY;

--
-- Name: message_revisions update_mine; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY update_mine ON app_public.message_revisions FOR UPDATE TO null814_cms_app_users USING ((editor_id = app_public.current_user_id())) WITH CHECK (((editor_id = app_public.current_user_id()) AND (NOT (EXISTS ( SELECT
   FROM app_public.message_revisions children
  WHERE (children.parent_revision_id = message_revisions.revision_id))))));


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

GRANT USAGE ON SCHEMA app_hidden TO null814_cms_app_users;


--
-- Name: SCHEMA app_public; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA app_public TO null814_cms_app_users;


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: -
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO null814_cms_app_users;


--
-- Name: FUNCTION auto_subscribe_after_space_creation(); Type: ACL; Schema: app_hidden; Owner: -
--

REVOKE ALL ON FUNCTION app_hidden.auto_subscribe_after_space_creation() FROM PUBLIC;
GRANT ALL ON FUNCTION app_hidden.auto_subscribe_after_space_creation() TO null814_cms_app_users;


--
-- Name: FUNCTION rebase_message_revisions_before_deletion(); Type: ACL; Schema: app_hidden; Owner: -
--

REVOKE ALL ON FUNCTION app_hidden.rebase_message_revisions_before_deletion() FROM PUBLIC;
GRANT ALL ON FUNCTION app_hidden.rebase_message_revisions_before_deletion() TO null814_cms_app_users;


--
-- Name: FUNCTION refresh_user_abilities_per_organization_on_update(); Type: ACL; Schema: app_hidden; Owner: -
--

REVOKE ALL ON FUNCTION app_hidden.refresh_user_abilities_per_organization_on_update() FROM PUBLIC;
GRANT ALL ON FUNCTION app_hidden.refresh_user_abilities_per_organization_on_update() TO null814_cms_app_users;


--
-- Name: FUNCTION refresh_user_abilities_per_organization_when_memberships_change(); Type: ACL; Schema: app_hidden; Owner: -
--

REVOKE ALL ON FUNCTION app_hidden.refresh_user_abilities_per_organization_when_memberships_change() FROM PUBLIC;
GRANT ALL ON FUNCTION app_hidden.refresh_user_abilities_per_organization_when_memberships_change() TO null814_cms_app_users;


--
-- Name: FUNCTION refresh_user_abilities_per_space_when_memberships_change(); Type: ACL; Schema: app_hidden; Owner: -
--

REVOKE ALL ON FUNCTION app_hidden.refresh_user_abilities_per_space_when_memberships_change() FROM PUBLIC;
GRANT ALL ON FUNCTION app_hidden.refresh_user_abilities_per_space_when_memberships_change() TO null814_cms_app_users;


--
-- Name: FUNCTION refresh_user_abilities_per_space_when_subscriptions_change(); Type: ACL; Schema: app_hidden; Owner: -
--

REVOKE ALL ON FUNCTION app_hidden.refresh_user_abilities_per_space_when_subscriptions_change() FROM PUBLIC;
GRANT ALL ON FUNCTION app_hidden.refresh_user_abilities_per_space_when_subscriptions_change() TO null814_cms_app_users;


--
-- Name: FUNCTION restrict_ability_updates_on_space_subscriptions(); Type: ACL; Schema: app_hidden; Owner: -
--

REVOKE ALL ON FUNCTION app_hidden.restrict_ability_updates_on_space_subscriptions() FROM PUBLIC;
GRANT ALL ON FUNCTION app_hidden.restrict_ability_updates_on_space_subscriptions() TO null814_cms_app_users;


--
-- Name: FUNCTION update_active_or_current_message_revision(); Type: ACL; Schema: app_hidden; Owner: -
--

REVOKE ALL ON FUNCTION app_hidden.update_active_or_current_message_revision() FROM PUBLIC;
GRANT ALL ON FUNCTION app_hidden.update_active_or_current_message_revision() TO null814_cms_app_users;


--
-- Name: FUNCTION assert_valid_password(new_password text); Type: ACL; Schema: app_private; Owner: -
--

REVOKE ALL ON FUNCTION app_private.assert_valid_password(new_password text) FROM PUBLIC;


--
-- Name: TABLE users; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT ON TABLE app_public.users TO null814_cms_app_users;


--
-- Name: COLUMN users.username; Type: ACL; Schema: app_public; Owner: -
--

GRANT UPDATE(username) ON TABLE app_public.users TO null814_cms_app_users;


--
-- Name: COLUMN users.name; Type: ACL; Schema: app_public; Owner: -
--

GRANT UPDATE(name) ON TABLE app_public.users TO null814_cms_app_users;


--
-- Name: COLUMN users.avatar_url; Type: ACL; Schema: app_public; Owner: -
--

GRANT UPDATE(avatar_url) ON TABLE app_public.users TO null814_cms_app_users;


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
GRANT ALL ON FUNCTION app_public.accept_invitation_to_organization(invitation_id uuid, code text) TO null814_cms_app_users;


--
-- Name: FUNCTION change_password(old_password text, new_password text); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.change_password(old_password text, new_password text) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.change_password(old_password text, new_password text) TO null814_cms_app_users;


--
-- Name: FUNCTION confirm_account_deletion(token text); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.confirm_account_deletion(token text) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.confirm_account_deletion(token text) TO null814_cms_app_users;


--
-- Name: TABLE organizations; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT ON TABLE app_public.organizations TO null814_cms_app_users;


--
-- Name: COLUMN organizations.slug; Type: ACL; Schema: app_public; Owner: -
--

GRANT UPDATE(slug) ON TABLE app_public.organizations TO null814_cms_app_users;


--
-- Name: COLUMN organizations.name; Type: ACL; Schema: app_public; Owner: -
--

GRANT UPDATE(name) ON TABLE app_public.organizations TO null814_cms_app_users;


--
-- Name: FUNCTION create_organization(slug public.citext, name text); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.create_organization(slug public.citext, name text) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.create_organization(slug public.citext, name text) TO null814_cms_app_users;


--
-- Name: FUNCTION current_session_id(); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.current_session_id() FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.current_session_id() TO null814_cms_app_users;


--
-- Name: FUNCTION "current_user"(); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public."current_user"() FROM PUBLIC;
GRANT ALL ON FUNCTION app_public."current_user"() TO null814_cms_app_users;


--
-- Name: FUNCTION current_user_first_member_organization_id(); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.current_user_first_member_organization_id() FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.current_user_first_member_organization_id() TO null814_cms_app_users;


--
-- Name: FUNCTION current_user_id(); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.current_user_id() FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.current_user_id() TO null814_cms_app_users;


--
-- Name: FUNCTION current_user_invited_organization_ids(); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.current_user_invited_organization_ids() FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.current_user_invited_organization_ids() TO null814_cms_app_users;


--
-- Name: FUNCTION current_user_member_organization_ids(); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.current_user_member_organization_ids() FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.current_user_member_organization_ids() TO null814_cms_app_users;


--
-- Name: FUNCTION delete_organization(organization_id uuid); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.delete_organization(organization_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.delete_organization(organization_id uuid) TO null814_cms_app_users;


--
-- Name: FUNCTION forgot_password(email public.citext); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.forgot_password(email public.citext) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.forgot_password(email public.citext) TO null814_cms_app_users;


--
-- Name: FUNCTION invite_to_organization(organization_id uuid, username public.citext, email public.citext); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.invite_to_organization(organization_id uuid, username public.citext, email public.citext) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.invite_to_organization(organization_id uuid, username public.citext, email public.citext) TO null814_cms_app_users;


--
-- Name: FUNCTION logout(); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.logout() FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.logout() TO null814_cms_app_users;


--
-- Name: TABLE user_emails; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT,DELETE ON TABLE app_public.user_emails TO null814_cms_app_users;


--
-- Name: COLUMN user_emails.email; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(email) ON TABLE app_public.user_emails TO null814_cms_app_users;


--
-- Name: FUNCTION make_email_primary(email_id uuid); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.make_email_primary(email_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.make_email_primary(email_id uuid) TO null814_cms_app_users;


--
-- Name: FUNCTION my_organization_ids(with_any_abilities app_public.ability[], with_all_abilities app_public.ability[]); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.my_organization_ids(with_any_abilities app_public.ability[], with_all_abilities app_public.ability[]) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.my_organization_ids(with_any_abilities app_public.ability[], with_all_abilities app_public.ability[]) TO null814_cms_app_users;


--
-- Name: FUNCTION my_space_ids(with_any_abilities app_public.ability[], with_all_abilities app_public.ability[]); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.my_space_ids(with_any_abilities app_public.ability[], with_all_abilities app_public.ability[]) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.my_space_ids(with_any_abilities app_public.ability[], with_all_abilities app_public.ability[]) TO null814_cms_app_users;


--
-- Name: FUNCTION my_space_subscription_ids(); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.my_space_subscription_ids() FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.my_space_subscription_ids() TO null814_cms_app_users;


--
-- Name: FUNCTION organization_for_invitation(invitation_id uuid, code text); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.organization_for_invitation(invitation_id uuid, code text) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.organization_for_invitation(invitation_id uuid, code text) TO null814_cms_app_users;


--
-- Name: FUNCTION organizations_current_user_is_billing_contact(org app_public.organizations); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.organizations_current_user_is_billing_contact(org app_public.organizations) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.organizations_current_user_is_billing_contact(org app_public.organizations) TO null814_cms_app_users;


--
-- Name: FUNCTION organizations_current_user_is_owner(org app_public.organizations); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.organizations_current_user_is_owner(org app_public.organizations) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.organizations_current_user_is_owner(org app_public.organizations) TO null814_cms_app_users;


--
-- Name: FUNCTION remove_from_organization(organization_id uuid, user_id uuid); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.remove_from_organization(organization_id uuid, user_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.remove_from_organization(organization_id uuid, user_id uuid) TO null814_cms_app_users;


--
-- Name: FUNCTION request_account_deletion(); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.request_account_deletion() FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.request_account_deletion() TO null814_cms_app_users;


--
-- Name: FUNCTION resend_email_verification_code(email_id uuid); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.resend_email_verification_code(email_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.resend_email_verification_code(email_id uuid) TO null814_cms_app_users;


--
-- Name: FUNCTION tg__graphql_subscription(); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.tg__graphql_subscription() FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.tg__graphql_subscription() TO null814_cms_app_users;


--
-- Name: FUNCTION tg_user_emails__forbid_if_verified(); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.tg_user_emails__forbid_if_verified() FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.tg_user_emails__forbid_if_verified() TO null814_cms_app_users;


--
-- Name: FUNCTION tg_user_emails__prevent_delete_last_email(); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.tg_user_emails__prevent_delete_last_email() FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.tg_user_emails__prevent_delete_last_email() TO null814_cms_app_users;


--
-- Name: FUNCTION tg_user_emails__verify_account_on_verified(); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.tg_user_emails__verify_account_on_verified() FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.tg_user_emails__verify_account_on_verified() TO null814_cms_app_users;


--
-- Name: FUNCTION tg_users__deletion_organization_checks_and_actions(); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.tg_users__deletion_organization_checks_and_actions() FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.tg_users__deletion_organization_checks_and_actions() TO null814_cms_app_users;


--
-- Name: FUNCTION transfer_organization_billing_contact(organization_id uuid, user_id uuid); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.transfer_organization_billing_contact(organization_id uuid, user_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.transfer_organization_billing_contact(organization_id uuid, user_id uuid) TO null814_cms_app_users;


--
-- Name: FUNCTION transfer_organization_ownership(organization_id uuid, user_id uuid); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.transfer_organization_ownership(organization_id uuid, user_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.transfer_organization_ownership(organization_id uuid, user_id uuid) TO null814_cms_app_users;


--
-- Name: FUNCTION users_has_password(u app_public.users); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.users_has_password(u app_public.users) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.users_has_password(u app_public.users) TO null814_cms_app_users;


--
-- Name: FUNCTION verify_email(user_email_id uuid, token text); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.verify_email(user_email_id uuid, token text) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.verify_email(user_email_id uuid, token text) TO null814_cms_app_users;


--
-- Name: FUNCTION procrastinate_defer_job(queue_name character varying, task_name character varying, lock text, queueing_lock text, args jsonb, scheduled_at timestamp with time zone); Type: ACL; Schema: procrastinate; Owner: -
--

REVOKE ALL ON FUNCTION procrastinate.procrastinate_defer_job(queue_name character varying, task_name character varying, lock text, queueing_lock text, args jsonb, scheduled_at timestamp with time zone) FROM PUBLIC;


--
-- Name: FUNCTION procrastinate_defer_periodic_job(_queue_name character varying, _lock character varying, _queueing_lock character varying, _task_name character varying, _defer_timestamp bigint); Type: ACL; Schema: procrastinate; Owner: -
--

REVOKE ALL ON FUNCTION procrastinate.procrastinate_defer_periodic_job(_queue_name character varying, _lock character varying, _queueing_lock character varying, _task_name character varying, _defer_timestamp bigint) FROM PUBLIC;


--
-- Name: FUNCTION procrastinate_defer_periodic_job(_queue_name character varying, _lock character varying, _queueing_lock character varying, _task_name character varying, _periodic_id character varying, _defer_timestamp bigint, _args jsonb); Type: ACL; Schema: procrastinate; Owner: -
--

REVOKE ALL ON FUNCTION procrastinate.procrastinate_defer_periodic_job(_queue_name character varying, _lock character varying, _queueing_lock character varying, _task_name character varying, _periodic_id character varying, _defer_timestamp bigint, _args jsonb) FROM PUBLIC;


--
-- Name: FUNCTION procrastinate_fetch_job(target_queue_names character varying[]); Type: ACL; Schema: procrastinate; Owner: -
--

REVOKE ALL ON FUNCTION procrastinate.procrastinate_fetch_job(target_queue_names character varying[]) FROM PUBLIC;


--
-- Name: FUNCTION procrastinate_finish_job(job_id integer, end_status procrastinate.procrastinate_job_status); Type: ACL; Schema: procrastinate; Owner: -
--

REVOKE ALL ON FUNCTION procrastinate.procrastinate_finish_job(job_id integer, end_status procrastinate.procrastinate_job_status) FROM PUBLIC;


--
-- Name: FUNCTION procrastinate_finish_job(job_id integer, end_status procrastinate.procrastinate_job_status, next_scheduled_at timestamp with time zone); Type: ACL; Schema: procrastinate; Owner: -
--

REVOKE ALL ON FUNCTION procrastinate.procrastinate_finish_job(job_id integer, end_status procrastinate.procrastinate_job_status, next_scheduled_at timestamp with time zone) FROM PUBLIC;


--
-- Name: FUNCTION procrastinate_finish_job(job_id integer, end_status procrastinate.procrastinate_job_status, next_scheduled_at timestamp with time zone, delete_job boolean); Type: ACL; Schema: procrastinate; Owner: -
--

REVOKE ALL ON FUNCTION procrastinate.procrastinate_finish_job(job_id integer, end_status procrastinate.procrastinate_job_status, next_scheduled_at timestamp with time zone, delete_job boolean) FROM PUBLIC;


--
-- Name: FUNCTION procrastinate_notify_queue(); Type: ACL; Schema: procrastinate; Owner: -
--

REVOKE ALL ON FUNCTION procrastinate.procrastinate_notify_queue() FROM PUBLIC;


--
-- Name: FUNCTION procrastinate_retry_job(job_id integer, retry_at timestamp with time zone); Type: ACL; Schema: procrastinate; Owner: -
--

REVOKE ALL ON FUNCTION procrastinate.procrastinate_retry_job(job_id integer, retry_at timestamp with time zone) FROM PUBLIC;


--
-- Name: FUNCTION procrastinate_trigger_scheduled_events_procedure(); Type: ACL; Schema: procrastinate; Owner: -
--

REVOKE ALL ON FUNCTION procrastinate.procrastinate_trigger_scheduled_events_procedure() FROM PUBLIC;


--
-- Name: FUNCTION procrastinate_trigger_status_events_procedure_insert(); Type: ACL; Schema: procrastinate; Owner: -
--

REVOKE ALL ON FUNCTION procrastinate.procrastinate_trigger_status_events_procedure_insert() FROM PUBLIC;


--
-- Name: FUNCTION procrastinate_trigger_status_events_procedure_update(); Type: ACL; Schema: procrastinate; Owner: -
--

REVOKE ALL ON FUNCTION procrastinate.procrastinate_trigger_status_events_procedure_update() FROM PUBLIC;


--
-- Name: FUNCTION procrastinate_unlink_periodic_defers(); Type: ACL; Schema: procrastinate; Owner: -
--

REVOKE ALL ON FUNCTION procrastinate.procrastinate_unlink_periodic_defers() FROM PUBLIC;


--
-- Name: TABLE user_abilities_per_organization; Type: ACL; Schema: app_hidden; Owner: -
--

GRANT SELECT ON TABLE app_hidden.user_abilities_per_organization TO null814_cms_app_users;


--
-- Name: TABLE message_revisions; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT,DELETE ON TABLE app_public.message_revisions TO null814_cms_app_users;


--
-- Name: COLUMN message_revisions.id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(id) ON TABLE app_public.message_revisions TO null814_cms_app_users;


--
-- Name: COLUMN message_revisions.parent_revision_id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(parent_revision_id) ON TABLE app_public.message_revisions TO null814_cms_app_users;


--
-- Name: COLUMN message_revisions.editor_id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(editor_id) ON TABLE app_public.message_revisions TO null814_cms_app_users;


--
-- Name: COLUMN message_revisions.update_comment; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(update_comment),UPDATE(update_comment) ON TABLE app_public.message_revisions TO null814_cms_app_users;


--
-- Name: COLUMN message_revisions.subject; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(subject),UPDATE(subject) ON TABLE app_public.message_revisions TO null814_cms_app_users;


--
-- Name: COLUMN message_revisions.body; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(body),UPDATE(body) ON TABLE app_public.message_revisions TO null814_cms_app_users;


--
-- Name: TABLE active_message_revisions; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT,DELETE ON TABLE app_public.active_message_revisions TO null814_cms_app_users;


--
-- Name: COLUMN active_message_revisions.id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(id) ON TABLE app_public.active_message_revisions TO null814_cms_app_users;


--
-- Name: COLUMN active_message_revisions.parent_revision_id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(parent_revision_id) ON TABLE app_public.active_message_revisions TO null814_cms_app_users;


--
-- Name: COLUMN active_message_revisions.editor_id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(editor_id),UPDATE(editor_id) ON TABLE app_public.active_message_revisions TO null814_cms_app_users;


--
-- Name: COLUMN active_message_revisions.update_comment; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(update_comment),UPDATE(update_comment) ON TABLE app_public.active_message_revisions TO null814_cms_app_users;


--
-- Name: COLUMN active_message_revisions.subject; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(subject),UPDATE(subject) ON TABLE app_public.active_message_revisions TO null814_cms_app_users;


--
-- Name: COLUMN active_message_revisions.body; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(body),UPDATE(body) ON TABLE app_public.active_message_revisions TO null814_cms_app_users;


--
-- Name: TABLE current_message_revisions; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT,DELETE ON TABLE app_public.current_message_revisions TO null814_cms_app_users;


--
-- Name: COLUMN current_message_revisions.id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(id) ON TABLE app_public.current_message_revisions TO null814_cms_app_users;


--
-- Name: COLUMN current_message_revisions.parent_revision_id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(parent_revision_id) ON TABLE app_public.current_message_revisions TO null814_cms_app_users;


--
-- Name: COLUMN current_message_revisions.editor_id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(editor_id),UPDATE(editor_id) ON TABLE app_public.current_message_revisions TO null814_cms_app_users;


--
-- Name: COLUMN current_message_revisions.update_comment; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(update_comment),UPDATE(update_comment) ON TABLE app_public.current_message_revisions TO null814_cms_app_users;


--
-- Name: COLUMN current_message_revisions.subject; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(subject),UPDATE(subject) ON TABLE app_public.current_message_revisions TO null814_cms_app_users;


--
-- Name: COLUMN current_message_revisions.body; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(body),UPDATE(body) ON TABLE app_public.current_message_revisions TO null814_cms_app_users;


--
-- Name: TABLE organization_memberships; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT ON TABLE app_public.organization_memberships TO null814_cms_app_users;


--
-- Name: TABLE space_items; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT,DELETE ON TABLE app_public.space_items TO null814_cms_app_users;


--
-- Name: COLUMN space_items.id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(id) ON TABLE app_public.space_items TO null814_cms_app_users;


--
-- Name: COLUMN space_items.space_id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(space_id) ON TABLE app_public.space_items TO null814_cms_app_users;


--
-- Name: COLUMN space_items.editor_id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(editor_id) ON TABLE app_public.space_items TO null814_cms_app_users;


--
-- Name: COLUMN space_items.message_id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(message_id) ON TABLE app_public.space_items TO null814_cms_app_users;


--
-- Name: COLUMN space_items.revision_id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(revision_id),UPDATE(revision_id) ON TABLE app_public.space_items TO null814_cms_app_users;


--
-- Name: TABLE space_subscriptions; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT,DELETE ON TABLE app_public.space_subscriptions TO null814_cms_app_users;


--
-- Name: COLUMN space_subscriptions.id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(id) ON TABLE app_public.space_subscriptions TO null814_cms_app_users;


--
-- Name: COLUMN space_subscriptions.space_id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(space_id) ON TABLE app_public.space_subscriptions TO null814_cms_app_users;


--
-- Name: COLUMN space_subscriptions.subscriber_id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(subscriber_id) ON TABLE app_public.space_subscriptions TO null814_cms_app_users;


--
-- Name: COLUMN space_subscriptions.abilities; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(abilities),UPDATE(abilities) ON TABLE app_public.space_subscriptions TO null814_cms_app_users;


--
-- Name: COLUMN space_subscriptions.is_receiving_notifications; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(is_receiving_notifications),UPDATE(is_receiving_notifications) ON TABLE app_public.space_subscriptions TO null814_cms_app_users;


--
-- Name: COLUMN space_subscriptions.last_visit_at; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(last_visit_at),UPDATE(last_visit_at) ON TABLE app_public.space_subscriptions TO null814_cms_app_users;


--
-- Name: TABLE spaces; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT,DELETE ON TABLE app_public.spaces TO null814_cms_app_users;


--
-- Name: COLUMN spaces.id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(id) ON TABLE app_public.spaces TO null814_cms_app_users;


--
-- Name: COLUMN spaces.organization_id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(organization_id),UPDATE(organization_id) ON TABLE app_public.spaces TO null814_cms_app_users;


--
-- Name: COLUMN spaces.creator_id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(creator_id) ON TABLE app_public.spaces TO null814_cms_app_users;


--
-- Name: COLUMN spaces.name; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(name),UPDATE(name) ON TABLE app_public.spaces TO null814_cms_app_users;


--
-- Name: COLUMN spaces.slug; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(slug),UPDATE(slug) ON TABLE app_public.spaces TO null814_cms_app_users;


--
-- Name: COLUMN spaces.is_public; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(is_public),UPDATE(is_public) ON TABLE app_public.spaces TO null814_cms_app_users;


--
-- Name: TABLE user_authentications; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT,DELETE ON TABLE app_public.user_authentications TO null814_cms_app_users;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: app_hidden; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE null814_cms_owner IN SCHEMA app_hidden GRANT SELECT,USAGE ON SEQUENCES TO null814_cms_app_users;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: app_hidden; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE null814_cms_owner IN SCHEMA app_hidden GRANT ALL ON FUNCTIONS TO null814_cms_app_users;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: app_public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE null814_cms_owner IN SCHEMA app_public GRANT SELECT,USAGE ON SEQUENCES TO null814_cms_app_users;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: app_public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE null814_cms_owner IN SCHEMA app_public GRANT ALL ON FUNCTIONS TO null814_cms_app_users;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE null814_cms_owner IN SCHEMA public GRANT SELECT,USAGE ON SEQUENCES TO null814_cms_app_users;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE null814_cms_owner IN SCHEMA public GRANT ALL ON FUNCTIONS TO null814_cms_app_users;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: -; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE null814_cms_owner REVOKE ALL ON FUNCTIONS FROM PUBLIC;


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

