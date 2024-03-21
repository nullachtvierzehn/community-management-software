-- Deploy 0814-cms:space-subscriptions/all-abilities to pg
-- requires: users/view-for-space-abilities

BEGIN;

create or replace function app_public.space_subscriptions_all_abilities(s app_public.space_items)
returns app_public.ability[]
language sql
stable
parallel safe
as $$
  select abilities
  from app_hidden.user_abilities_per_space
  where
    space_id = s.id
    and user_id = app_public.current_user_id()
$$;

comment on function app_public.space_subscriptions_all_abilities(s app_public.space_items) is $$
  @behavior +filterBy +typeField
  $$;


create or replace function app_public.space_subscriptions_all_abilities_with_grant_option(s app_public.space_items)
returns app_public.ability[]
language sql
stable
parallel safe
as $$
  select abilities_with_grant_option
  from app_hidden.user_abilities_per_space
  where
    space_id = s.id
    and user_id = app_public.current_user_id()
$$;

comment on function app_public.space_subscriptions_all_abilities_with_grant_option(s app_public.space_items) is $$
  @behavior +filterBy +typeField
  $$;

COMMIT;
