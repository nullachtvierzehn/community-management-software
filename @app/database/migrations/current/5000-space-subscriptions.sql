create type app_public.space_role as enum (
  'viewer',
  'contributor',
  'moderator',
  'admin'
);

create type app_public.space_capability as enum (
  'submissions__create',
  'submissions__accept',
  'posts__view',
  'posts__create',
  'posts__revise_own',
  'posts__revise_all',
  'contents__edit_own',
  'contents__edit_all'
);


create table app_public.space_subscriptions (
  id uuid primary key default uuid_generate_v1mc(),
  space_id uuid 
    constraint "space"
      references app_public.spaces (id)
      on update cascade on delete cascade,
  subscriber_id uuid
    constraint subscriber
      references app_public.users (id)
      on update cascade on delete cascade,
  "role" app_public.space_role not null default 'contributor',
  capabilities app_public.space_capability[] not null default '{posts__view}',
  notifications app_public.notification_setting not null default 'default',
  last_visit_at timestamptz,
  last_notification_at timestamptz,
  is_starred boolean not null default false,
  created_at timestamptz not null default current_timestamp,
  updated_at timestamptz not null default current_timestamp
);

comment on constraint "space" on app_public.space_subscriptions 
  is E'@foreignFieldName subscriptions';

grant select on app_public.space_subscriptions to :DATABASE_VISITOR;


create or replace function app_public.my_subscribed_space_ids(
  minimum_role app_public.space_role = null,
  minimum_capabilities app_public.space_capability[] = null
) 
  returns setof uuid
  language sql 
  stable 
  parallel safe 
  security definer 
  set search_path to pg_catalog, public, pg_temp 
as $$
  select space_id 
  from app_public.space_subscriptions 
  where 
    subscriber_id = app_public.current_user_id() 
    and (minimum_role is null or "role" >= minimum_role)
    and (minimum_capabilities is null or capabilities @> minimum_capabilities)
$$;

grant execute on function app_public.my_subscribed_space_ids(app_public.space_role, app_public.space_capability[]) to :DATABASE_VISITOR;


create or replace function app_public.my_space_subscriptions(
  minimum_role app_public.space_role = null,
  minimum_capabilities app_public.space_capability[] = null
) 
  returns setof app_public.space_subscriptions
  language sql 
  stable 
  parallel safe
  rows 30
as $$
  select * 
  from app_public.space_subscriptions 
  where 
    subscriber_id = app_public.current_user_id()
    and (minimum_role is null or "role" >= minimum_role)
    and (minimum_capabilities is null or capabilities @> minimum_capabilities)
$$;

grant execute on function app_public.my_space_subscriptions(app_public.space_role, app_public.space_capability[]) to :DATABASE_VISITOR;


create function app_public.spaces_n_subscriptions(
  s app_public.spaces,
  minimum_role app_public.space_role = null,
  minimum_capabilities app_public.space_capability[] = null
)
  returns bigint
  language sql
  stable
  parallel safe
as $$
  select count(*)
  from app_public.space_subscriptions
  where 
    space_id = s.id 
    and (minimum_role is null or "role" >= minimum_role)
    and (minimum_capabilities is null or capabilities @> minimum_capabilities)
$$;

grant execute on function app_public.spaces_n_subscriptions(app_public.spaces, app_public.space_role, app_public.space_capability[]) to :DATABASE_VISITOR;

comment on function app_public.spaces_n_subscriptions(app_public.spaces, app_public.space_role, app_public.space_capability[]) is $$
  @behavior +typeField +orderBy +filterBy
  $$;


create or replace function app_public.spaces_has_subscriptions(
  s app_public.spaces,
  minimum_role app_public.space_role = null,
  minimum_capabilities app_public.space_capability[] = null
)
  returns boolean
  language sql
  stable
  parallel safe
  security definer 
as $$
  select exists (
    select from app_public.space_subscriptions
    where 
      space_id = s.id 
      and (minimum_role is null or "role" >= minimum_role)
      and (minimum_capabilities is null or capabilities @> minimum_capabilities)
  )
$$;

grant execute on function app_public.spaces_has_subscriptions(app_public.spaces, app_public.space_role, app_public.space_capability[]) to :DATABASE_VISITOR;

comment on function app_public.spaces_has_subscriptions(app_public.spaces, app_public.space_role, app_public.space_capability[]) is $$
  @behavior +typeField +filterBy
  $$;


create or replace function app_public.spaces_my_subscription(s app_public.spaces)
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

grant execute on function app_public.spaces_my_subscription(app_public.spaces) to :DATABASE_VISITOR;
