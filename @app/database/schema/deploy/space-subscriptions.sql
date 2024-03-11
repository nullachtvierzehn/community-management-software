-- Deploy 0814-cms:space-subscriptions to pg
-- requires: spaces
-- requires: initial

BEGIN;

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
  abilities app_public.ability[] not null default '{view}',
  is_receiving_notifications boolean not null default false,
  last_visit_at timestamptz,
  last_notification_at timestamptz,
  created_at timestamptz not null default current_timestamp,
  updated_at timestamptz not null default current_timestamp
);

alter table app_public.space_subscriptions enable row level security;

comment on constraint "space" on app_public.space_subscriptions 
  is E'@foreignFieldName subscriptions';

grant select on app_public.space_subscriptions to "$DATABASE_VISITOR";

-- auto-update updated_at
create trigger _200_timestamps
  before insert or update on app_public.space_subscriptions
  for each row
  execute procedure app_private.tg__timestamps();

COMMIT;
