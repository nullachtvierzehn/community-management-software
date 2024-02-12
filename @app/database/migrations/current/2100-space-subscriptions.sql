create type app_public.space_role as enum (
  'guest',
  'member',
  'staff',
  'admin'
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
  "role" app_public.space_role not null default 'member',
  notifications app_public.notification_setting not null default 'default',
  last_visit_at timestamptz,
  last_notification_at timestamptz,
  is_starred boolean not null default false,
  created_at timestamptz not null default current_timestamp,
  updated_at timestamptz not null default current_timestamp
);

comment on constraint "space" on app_public.space_subscriptions 
  is E'@foreignFieldName subscriptions';



create or replace function app_public.my_subscribed_space_ids(minimum_role app_public.space_role default 'member') 
  returns setof uuid
  language sql 
  stable 
  parallel safe 
  security definer 
  set search_path to pg_catalog, public, pg_temp 
  as $$
    select space_id from app_public.space_subscriptions where subscriber_id = app_public.current_user_id() and "role" >= minimum_role;
  $$;

create or replace function app_public.my_space_subscriptions(minimum_role app_public.space_role default 'member') returns setof app_public.space_subscriptions as $$
  select * from app_public.space_subscriptions where subscriber_id = app_public.current_user_id() and "role" >= minimum_role;
$$ language sql stable parallel safe security definer set search_path = pg_catalog, public, pg_temp;
