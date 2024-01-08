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
  constraint is_a_valid_topic check (
    not (type = 'TOPIC' and contributed_at is not null) or (topic_id is not null)
  ),
  constraint is_a_valid_non_topic check (
    not (type <> 'TOPIC') or (topic_id is null)
  ),

  -- messages
  message_body jsonb,
  constraint is_a_valid_message check (
    not (
      type = 'MESSAGE'
      and contributed_at is not null
    ) or (
      message_body is not null
      and jsonb_typeof(message_body) = 'object'
    )
  ),
  constraint is_a_valid_non_message check (
    not (type <> 'MESSAGE') or (message_body is null)
  )
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
create index room_items_on_updated_at on app_public.room_items (updated_at);
create index room_items_on_contributed_at on app_public.room_items (contributed_at);
create index room_items_on_contributed_at_and_room_id on app_public.room_items (room_id, contributed_at);

grant select on app_public.room_items to :DATABASE_VISITOR;
grant insert (type, room_id, parent_id, contributor_id, "order", contributed_at, is_visible_for, is_visible_since, is_visible_since_date, message_body, topic_id) on app_public.room_items to :DATABASE_VISITOR;
grant update ("order", parent_id, contributed_at, is_visible_for, is_visible_since, is_visible_since_date, message_body, topic_id) on app_public.room_items to :DATABASE_VISITOR;
grant delete on app_public.room_items to :DATABASE_VISITOR;

create or replace function app_hidden.increment_last_visit_when_contributing_items()
  returns trigger
  language plpgsql
  volatile
  security definer
  set search_path = pg_catalog, public, pg_temp
as $$
declare
  item alias for new;
begin
  update app_public.room_subscriptions 
    set last_visit_at = greatest(last_visit_at, item.contributed_at)
  where 
    subscriber_id = item.contributor_id
    and room_id = item.room_id
    and item.contributed_at is not null;
    
  return new;
end;
$$;

create trigger _100_timestamps
  before insert or update on app_public.room_items
  for each row
  execute procedure app_private.tg__timestamps();

create trigger _900_send_notifications
  after insert or update of contributed_at
  on app_public.room_items
  for each row
  when (NEW.contributed_at is not null)
  execute procedure app_private.tg__add_job('room_items__send_notifications');

create trigger _800_increment_last_visit_when_contributing_items
  after insert or update of contributed_at
  on app_public.room_items
  for each row
  when (NEW.contributed_at is not null)
  execute procedure app_hidden.increment_last_visit_when_contributing_items();

alter table app_public.room_items enable row level security;

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
    join lateral (
      select coalesce(room_items.is_visible_for, case
        when room_items.contributed_at is null then r.draft_items_are_visible_for
        else r.items_are_visible_for
      end) as is_visible_for
    ) as this_item on (true)
    where
      -- Does apply to the room of the item and the client's subscribtion, if any.
      r.id = room_items.room_id
      and s."role" is distinct from 'banned'
      -- Everybody can see public items, even if currently signed out.
      and case this_item.is_visible_for
        when 'public'
          then true
        else 
          s."role" >= this_item.is_visible_for
      end
      and case coalesce(room_items.is_visible_since, r.items_are_visible_since) 
        when 'always' 
          then true
        when 'specified_date' 
          then room_items.contributed_at >= coalesce(room_items.is_visible_since_date, r.items_are_visible_since_date)
        else 
          room_items.contributed_at is null or room_items.contributed_at >= s.created_at
      end 
  ));

create policy manage_by_admins
  on app_public.room_items
  for all
  using (room_id in (select app_public.my_subscribed_room_ids('admin')));


create or replace function app_public.n_items(room app_public.rooms)
  returns bigint
  language sql
  stable
  parallel safe
as $$
  select count(*) 
  from app_public.room_items 
  where 
    room_id = room.id 
    and contributed_at is not null
$$;

grant execute on function app_public.n_items(app_public.rooms) to :DATABASE_VISITOR; 
comment on function app_public.n_items(app_public.rooms)
  is E'@behavior +typeField +orderBy +filterBy';


create or replace function app_public.n_items_since(room app_public.rooms, "interval" interval)
  returns bigint
  language sql
  stable
  parallel safe
as $$
  select count(*) 
  from app_public.room_items 
  where 
    room_id = room.id 
    and contributed_at is not null
    and contributed_at > (now() - "interval")
$$;

grant execute on function app_public.n_items_since(app_public.rooms, interval) to :DATABASE_VISITOR; 
comment on function app_public.n_items_since(app_public.rooms, interval)
  is E'@behavior +typeField +orderBy +filterBy';


create or replace function app_public.n_items_since_date(room app_public.rooms, "date" timestamptz)
  returns bigint
  language sql
  stable
  parallel safe
as $$
  select count(*) 
  from app_public.room_items 
  where 
    room_id = room.id 
    and contributed_at is not null
    and contributed_at > "date"
$$;

grant execute on function app_public.n_items_since_date(app_public.rooms, timestamptz) to :DATABASE_VISITOR; 
comment on function app_public.n_items_since_date(app_public.rooms, timestamptz)
  is E'@behavior +typeField +orderBy +filterBy';


create or replace function app_public.n_items_since_last_visit(room app_public.rooms)
  returns bigint
  language sql
  stable
  parallel safe
as $$
  select count(*) 
  from app_public.my_room_subscription(room) as s
  join app_public.room_items as i on (i.contributed_at > s.last_visit_at)
  where 
    i.room_id = room.id
$$;

grant execute on function app_public.n_items_since_last_visit(app_public.rooms) to :DATABASE_VISITOR;
comment on function app_public.n_items_since_last_visit(app_public.rooms)
  is E'@behavior +typeField +orderBy +filterBy';


create function app_public.latest_item(room app_public.rooms)
returns app_public.room_items
language sql
stable
parallel safe
as $$
  select *
  from app_public.room_items
  where
    room_id = room.id
    and contributed_at is not null
  order by contributed_at desc
  limit 1
$$;

grant execute on function app_public.latest_item(app_public.rooms) to :DATABASE_VISITOR;
comment on function app_public.latest_item(app_public.rooms) is E'@behavior typeField';


create function app_public.latest_item_contributed_at(room app_public.rooms)
returns timestamptz
language sql
stable
parallel safe
as $$
  select max(contributed_at)
  from app_public.room_items
  where
    room_id = room.id
    and contributed_at is not null
$$;

grant execute on function app_public.latest_item_contributed_at(app_public.rooms) to :DATABASE_VISITOR;
comment on function app_public.latest_item_contributed_at(app_public.rooms) is E'@behavior typeField +orderBy +filterBy';


create function app_public.nth_item_since_last_visit(item app_public.room_items)
returns bigint
language sql
stable
parallel safe
as $$
  with items_in_same_room as (
    select 
    ri.id as item_id,
    ri.room_id,
    case 
      when ri.contributed_at > s.last_visit_at
      then row_number() over (
        partition by ri.room_id, ri.contributed_at > s.last_visit_at
        order by ri.contributed_at asc
      )
      when ri.contributed_at <= s.last_visit_at
      then -1 * row_number() over (
        partition by ri.room_id, ri.contributed_at > s.last_visit_at
        order by ri.contributed_at desc
      )
    end as n
    from app_public.room_items as ri
    join app_public.rooms as r on (ri.room_id = r.id)
    join lateral app_public.my_room_subscription(r) as s on (true)
    where ri.contributed_at is not null
  )
  select n 
  from items_in_same_room 
  where 
    items_in_same_room.item_id = item.id
    and items_in_same_room.room_id = item.room_id
$$;

grant execute on function app_public.nth_item_since_last_visit(app_public.room_items) to :DATABASE_VISITOR;
comment on function app_public.nth_item_since_last_visit(app_public.room_items) is E'@behavior typeField +orderBy +filterBy';