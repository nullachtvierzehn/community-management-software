create type app_public.room_item_type as enum (
  'MESSAGE',
  'TOPIC'
);

create table app_public.room_items (
  id uuid primary key default uuid_generate_v1mc(),

  -- rails-style polymorphic column
  type app_public.room_item_type not null default 'MESSAGE',

  -- shared attributes
  room_id uuid not null
    constraint room
      references app_public.rooms (id)
      on update cascade on delete cascade,
  parent_id uuid
    constraint parent
      references app_public.room_items (id)
      on update cascade on delete cascade,
  contributor_id uuid
    default app_public.current_user_id()
    constraint contributor
      references app_public.users (id)
      on update cascade on delete set null,
  "order" float4 not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  contributed_at timestamptz, 
  is_visible_for app_public.room_role,
  is_visible_since app_public.room_history_visibility,
  is_visible_since_date timestamptz,

  -- attached topics
  topic_id uuid
    constraint topic
    references app_public.topics (id)
    on update cascade on delete cascade,
  constraint valid_topic_id check (
    (type = 'TOPIC') = (topic_id is not null)
  ),

  -- messages
  message_body jsonb,
  constraint valid_message_body check ((
    type = 'MESSAGE'
    and message_body is not null
    and jsonb_typeof(message_body) = 'object'
  ) or (
    type <> 'MESSAGE'
    and message_body is null
  ))
);

comment on table app_public.room_items is
  E'Room items are messages or materials, that are accessible within a certain room.';
comment on constraint room on app_public.room_items is
  E'@foreignFieldName items';
comment on column app_public.room_items.type is 
  E'The kind of room item. There are messages, pages, files, and so on.';
comment on column app_public.room_items.parent_id is 
  E'The items in a room can be connected to each other, basically forming one or multiple trees. For example, you can use this to keep track of conversations.';
comment on constraint parent on app_public.room_items is
  E'@foreignFieldName children\nRoom items can be related in trees.';
comment on column app_public.room_items.contributor_id is 
  E'The id of a user who contributed the room item.';
comment on constraint contributor on app_public.room_items is
  E'@foreignFieldName roomItems';
comment on column app_public.room_items."order" is 
  E'The default order is 0, but you can change it to different values to sort the items.';
comment on column app_public.room_items.is_visible_for is
  E'Decides which role can see the room item. This also applies to more powerful roles. If the value is not set, the default settings of the room will be used.';
comment on column app_public.room_items.is_visible_since is 
  E'Decides if room items are always visible or only to users who subscribed before they were added. If the value is not set, the default settings of the room will be used.';

create index room_items_on_room_id_and_order on app_public.room_items (room_id, "order");
create index room_items_on_parent_id on app_public.room_items (parent_id);
create index room_items_on_contributor_id on app_public.room_items (contributor_id);
create index room_items_on_created_at on app_public.room_items using brin (created_at);
create index room_items_on_updated_at on app_public.room_items using brin (updated_at);

grant select on app_public.room_items to :DATABASE_VISITOR;
grant insert (type, room_id, parent_id, contributor_id, "order", contributed_at, is_visible_for, is_visible_since, is_visible_since_date, message_body, topic_id) on app_public.room_items to :DATABASE_VISITOR;
grant update ("order", contributed_at, is_visible_for, is_visible_since, is_visible_since_date, message_body, topic_id) on app_public.room_items to :DATABASE_VISITOR;
grant delete on app_public.room_items to :DATABASE_VISITOR;

alter table app_public.room_items enable row level security;

create policy hide_my_drafts_from_others
  on app_public.room_items
  as restrictive
  for all
  using (
    contributed_at is not null
    or contributor_id = app_public.current_user_id()
  );

create policy manage_my_drafts
  on app_public.room_items
  for all
  using (
    contributed_at is null
    and contributor_id = app_public.current_user_id()
  );

create policy show_mine
  on app_public.room_items
  for select
  using (contributor_id = app_public.current_user_id());

create policy update_mine
  on app_public.room_items
  for update
  using (contributor_id = app_public.current_user_id());

create policy show_others_to_members
  on app_public.room_items
  for select
  using (exists(
    select from app_public.rooms as r
    left join lateral app_public.my_room_subscription(in_room => r) as s on (true)
    where 
      r.id = room_items.room_id
      and s."role" is distinct from 'banned'
      and case coalesce(room_items.is_visible_for, r.items_are_visible_for)
        when 'public'
          then true
        else 
          s."role" >= coalesce(room_items.is_visible_for, r.items_are_visible_for)
      end
      and case coalesce(room_items.is_visible_since, r.items_are_visible_since) 
        when 'always' 
          then true
        when 'specified_date' 
          then room_items.contributed_at >= coalesce(room_items.is_visible_since_date, r.items_are_visible_since_date)
        else 
          room_items.contributed_at >= s.created_at
      end 
  ));

create policy manage_by_admins
  on app_public.room_items
  for all
  using (room_id in (select app_public.my_subscribed_room_ids('admin')));