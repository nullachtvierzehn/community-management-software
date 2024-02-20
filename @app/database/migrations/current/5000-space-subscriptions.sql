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


create or replace function app_public.my_subscribed_space_ids(minimum_role app_public.space_role default 'viewer') 
  returns setof uuid
  language sql 
  stable 
  parallel safe 
  security definer 
  set search_path to pg_catalog, public, pg_temp 
  as $$
    select space_id from app_public.space_subscriptions where subscriber_id = app_public.current_user_id() and "role" >= minimum_role;
  $$;

create or replace function app_public.my_space_subscriptions(minimum_role app_public.space_role default 'viewer') returns setof app_public.space_subscriptions as $$
  select * from app_public.space_subscriptions where subscriber_id = app_public.current_user_id() and "role" >= minimum_role;
$$ language sql stable parallel safe security definer set search_path = pg_catalog, public, pg_temp;
