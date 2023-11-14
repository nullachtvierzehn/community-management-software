create type app_public.room_role as enum (
  'banned',
  'prospect',
  'member',
  'moderator',
  'admin'
);

create type app_public.notification_setting as enum (
  'silenced',
  'default',
  'deferred',
  'immediate'
);

create table app_public.room_subscriptions (
  id uuid primary key default uuid_generate_v1mc(),
  room_id uuid not null
    constraint room
      references app_public.rooms (id)
      on update cascade on delete cascade,
  subscriber_id uuid not null
    default app_public.current_user_id()
    constraint sender
      references app_public.users (id)
      on update cascade on delete cascade,
  "role" app_public.room_role not null default 'member',
  notifications app_public.notification_setting not null default 'default',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint one_subscription_per_user_and_room
    unique (subscriber_id, room_id)
);

create index room_subscriptionson_room_id on app_public.room_subscriptions (room_id);
create index room_subscriptionson_subscriber_id on app_public.room_subscriptions (subscriber_id);
create index room_subscriptionson_created_at on app_public.room_subscriptions using brin (created_at);

comment on table app_public.room_subscriptions is
  E'Users can be subscribed to rooms.';
comment on column app_public.room_subscriptions.subscriber_id is
  E'The subscribing user.';
comment on column app_public.room_subscriptions.role is
  E'Maintainers can manage subscriptions and delete the room.';
comment on constraint room on app_public.room_subscriptions is
  E'@foreignFieldName subscriptions';

grant select on app_public.room_subscriptions to :DATABASE_VISITOR;
grant insert (room_id, subscriber_id) on app_public.room_subscriptions to :DATABASE_VISITOR;
grant update ("role", notifications) on app_public.room_subscriptions to :DATABASE_VISITOR;
grant delete on app_public.room_subscriptions to :DATABASE_VISITOR;


alter table app_public.users
  add column if not exists default_handling_of_notifications app_public.notification_setting not null default 'default',
  add column if not exists sending_time_for_deferred_notifications time not null default '20:00';

comment on column app_public.users.default_handling_of_notifications is
  E'Users can be notified about activities in the rooms they have subscribed to. This is the default setting. You can change it for each room.';
comment on column app_public.users.sending_time_for_deferred_notifications is
  E'If there are any delayed notifications, they are sent at this time every day.';

grant insert (default_handling_of_notifications, sending_time_for_deferred_notifications) on app_public.users to :DATABASE_VISITOR;
grant update (default_handling_of_notifications, sending_time_for_deferred_notifications) on app_public.users to :DATABASE_VISITOR;


create or replace function app_public.my_subscribed_room_ids(minimum_role app_public.room_role default 'member') returns setof uuid as $$
  select room_id from app_public.room_subscriptions where subscriber_id = app_public.current_user_id() and "role" >= minimum_role;
$$ language sql stable parallel safe security definer set search_path to pg_catalog, public, pg_temp;

create or replace function app_public.my_room_subscriptions(minimum_role app_public.room_role default 'member') returns setof app_public.room_subscriptions as $$
  select * from app_public.room_subscriptions where subscriber_id = app_public.current_user_id() and "role" >= minimum_role;
$$ language sql stable parallel safe security definer;

create function app_public.my_room_subscription(in_room app_public.rooms)
  returns app_public.room_subscriptions
  language sql
  stable
  parallel safe
as $$
  select *
  from app_public.room_subscriptions
  where (room_id, subscriber_id) = (in_room.id, app_public.current_user_id())
$$;

grant execute on function app_public.my_room_subscription(app_public.rooms) to :DATABASE_VISITOR;
comment on function app_public.my_room_subscription(app_public.rooms) is $$
@behavior typeField
@name mySubscription
$$;

create function app_public.my_room_subscription_id(in_room app_public.rooms)
  returns uuid
  language sql
  stable
  parallel safe
as $$
  select id
  from app_public.room_subscriptions
  where (room_id, subscriber_id) = (in_room.id, app_public.current_user_id())
$$;

grant execute on function app_public.my_room_subscription_id(app_public.rooms) to :DATABASE_VISITOR;
comment on function app_public.my_room_subscription(app_public.rooms) is $$
@behavior typeField
@filterable
@name mySubscriptionId
$$;

create function app_public.n_room_subscriptions(room app_public.rooms)
returns bigint
language sql
stable
parallel safe
as $$
  select count(*)
  from app_public.room_subscriptions
  where room_id = room.id
$$;

comment on function app_public.n_room_subscriptions(room app_public.rooms) is $$
@behavior typeField
@sortable
@filterable
@name nSubscriptions
$$;

-- Every subscriber should be able to see her or his rooms, even if private.
create policy show_subscribed on app_public.rooms for select using (id in (select app_public.my_subscribed_room_ids(minimum_role => 'banned')));
-- Maintainers should be able to update their rooms.
create policy manage_as_admin on app_public.rooms for all using (id in (select app_public.my_subscribed_room_ids(minimum_role => 'admin')));

alter table app_public.room_subscriptions enable row level security;
-- You should see your own room_subscriptions.
create policy select_own on app_public.room_subscriptions for select using (subscriber_id = app_public.current_user_id());
-- You should see others in your rooms.
create policy select_peers on app_public.room_subscriptions for select using (room_id in (select app_public.my_subscribed_room_ids()));
-- You should be able to unsubscribe from your rooms.
create policy delete_own on app_public.room_subscriptions for delete using (subscriber_id = app_public.current_user_id());
-- Maintainers can unsubscribe others from their rooms.
create policy manage_as_moderator on app_public.room_subscriptions for all using (id in (select app_public.my_subscribed_room_ids(minimum_role => 'moderator')));
-- You should be able to subscribe public rooms
create policy subscribe_rooms on app_public.room_subscriptions for insert with check (
  exists (
    select from app_public.rooms as r
    where 
      room_subscriptions.room_id = r.id
      and room_subscriptions.subscriber_id = app_public.current_user_id()
      and (
        -- You can become member of public rooms, or...
        (r.visibility >= 'public' and room_subscriptions."role" <= 'member')
        -- prospect in private rooms.
        or (r.visibility <= 'public' and room_subscriptions."role" <= 'prospect')
        -- You can take on all roles when creating a room. This is for the first admins.
        or (r.created_at = room_subscriptions.created_at)
        -- You can take on all roles in orphaned rooms.
        or (app_public.n_room_subscriptions(r) < 1)
      )
  )
);

create trigger _100_timestamps
  before insert or update on app_public.room_subscriptions
  for each row
  execute procedure app_private.tg__timestamps();
