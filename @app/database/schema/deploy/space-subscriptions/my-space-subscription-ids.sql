-- Deploy 0814-cms:space-subscriptions/my-space-subscriptions to pg
-- requires: space-subscriptions

BEGIN;

create or replace function app_public.my_space_subscription_ids()
  returns setof uuid
  language sql
  stable
  rows 30
  parallel safe
  security definer
  set search_path = pg_catalog, public, pg_temp
as $$
  select id 
  from app_public.space_subscriptions
  where subscriber_id = app_public.current_user_id()
$$;

COMMIT;
