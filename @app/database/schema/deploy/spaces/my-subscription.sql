-- Deploy 0814-cms:spaces/my-subscription to pg
-- requires: space-subscriptions

BEGIN;

create or replace function app_public.my_subscription(s app_public.spaces)
returns app_public.space_subscriptions
language sql
stable
parallel safe
as $$
  select *
  from app_public.space_subscriptions
  where
    space_id = s.id
    and subscriber_id = app_public.current_user_id()
$$;

comment on function app_public.my_subscription(s app_public.spaces) is E'@behavior +typeField +filterBy +proc:filterBy';

COMMIT;
