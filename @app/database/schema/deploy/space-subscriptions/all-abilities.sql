-- Deploy 0814-cms:space-subscriptions/all-abilities to pg
-- requires: users/view-for-space-abilities

BEGIN;

create or replace function app_public.space_subscriptions_all_abilities(s app_public.space_subscriptions)
returns app_public.ability[]
language sql
stable
parallel safe
as $$
  select abilities
  from app_hidden.user_abilities_per_space
  where
    space_id = s.space_id
    and "user_id" = s.subscriber_id
$$;

grant execute on function app_public.space_subscriptions_all_abilities(s app_public.space_subscriptions) to "$DATABASE_VISITOR";

comment on function app_public.space_subscriptions_all_abilities(s app_public.space_subscriptions) is E'@behavior +typeField +filterBy +proc:filterBy';


create or replace function app_public.space_subscriptions_all_abilities_with_grant_option(s app_public.space_subscriptions)
returns app_public.ability[]
language sql
stable
parallel safe
as $$
  select abilities_with_grant_option
  from app_hidden.user_abilities_per_space
  where
    space_id = s.space_id
    and "user_id" = s.subscriber_id
$$;

grant execute on function app_public.space_subscriptions_all_abilities_with_grant_option(s app_public.space_subscriptions) to "$DATABASE_VISITOR";

comment on function app_public.space_subscriptions_all_abilities_with_grant_option(s app_public.space_subscriptions) is E'@behavior +typeField +filterBy +proc:filterBy';

COMMIT;
