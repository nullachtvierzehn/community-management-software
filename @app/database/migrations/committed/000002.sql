--! Previous: sha1:eaf2866060caa0bba319236017c15a40d37a7815
--! Hash: sha1:49edd52c8823d3e17382ce3833cbb1a9b1cd0d85

--! split: 0001-reset.sql
drop table if exists app_public.room_item_attachments;
drop type if exists app_public.room_item_attachment_type;


drop table if exists app_public.pdf_files;
drop table if exists app_public.files;

drop function if exists app_public.latest_item(app_public.rooms);
drop function if exists app_public.latest_item_contributed_at(app_public.rooms);
drop function if exists app_public.latest_activity_at(room app_public.rooms);
drop function if exists app_public.nth_item_since_last_visit(item app_public.room_items);
drop table if exists app_public.room_items;
drop type if exists app_public.room_item_type;

drop table if exists app_public.room_message_attachments;

drop policy if exists select_if_public_or_subscribed on app_public.room_messages;
drop policy if exists send_messages_to_public_rooms on app_public.room_messages;
drop function if exists app_public.latest_message(room app_public.rooms);
drop function if exists app_public.fetch_draft_in_room(room_id uuid);
drop function if exists app_public.send_room_message(draft_id uuid);
drop function if exists app_public.my_first_interaction(room app_public.rooms);
drop index if exists app_public.room_messages_on_german_fulltext;
drop function if exists app_public.fulltext("message" app_public.room_messages);
drop table if exists app_public.room_messages;

alter table users 
  drop column if exists default_handling_of_notifications,
  drop column if exists sending_time_for_deferred_notifications;

drop policy if exists subscribe_rooms on app_public.room_subscriptions;
drop policy if exists show_subscribed on app_public.rooms;
drop policy if exists manage_as_admin on app_public.rooms;
drop policy if exists select_peers on app_public.room_subscriptions;
drop policy if exists manage_as_moderator on app_public.room_subscriptions;
drop function if exists app_public.my_subscribed_room_ids(app_public.room_role);
drop function if exists app_public.my_room_subscriptions(app_public.room_role);
drop function if exists app_public.my_room_subscription(app_public.rooms);
drop function if exists app_public.my_room_subscription_id(app_public.rooms);
drop function if exists app_public.n_room_subscriptions(room app_public.rooms);
drop function if exists app_public.n_room_subscriptions(room app_public.rooms, min_role app_public.room_role);
drop function if exists app_public.has_subscriptions(room app_public.rooms, min_role app_public.room_role);
drop table if exists app_public.room_subscriptions;
drop type if exists app_public.notification_setting;

drop function if exists app_public.n_items(room app_public.rooms);
drop function if exists app_public.n_items_since(room app_public.rooms, interval);
drop function if exists app_public.n_items_since_date(room app_public.rooms, timestamptz);
drop function if exists app_public.n_items_since_last_visit(room app_public.rooms);
drop table if exists app_public.rooms;
drop type if exists app_public.room_visibility;
drop type if exists app_public.room_history_visibility;
drop type if exists app_public.room_role;

drop function if exists app_public.topics_content_as_plain_text(topic app_public.topics);
drop function if exists app_public.topics_content_teaser(topic app_public.topics);
drop function if exists app_public.topics_content_preview(topic app_public.topics);
drop function if exists app_public.topics_content_preview(topic app_public.topics, integer);

drop table if exists app_public.topics;
drop type if exists app_public.topic_visibility;

drop function if exists app_public.current_user_first_organization_id();
create or replace function app_public.current_user_first_owned_organization_id() returns uuid as $$
  select organization_id 
  from app_public.organization_memberships
  where 
    user_id = app_public.current_user_id() 
    and is_owner = true
  order by created_at asc
  limit 1;
$$ language sql stable security definer set search_path = pg_catalog, public, pg_temp;

--! split: 0002-add-rooms.sql
create type app_public.room_visibility as enum (
  'subscribers',
  'organization_members',
  'signed_in_users',
  'public'
);

create type app_public.room_history_visibility as enum (
  'subscription',
  'invitation',
  'specified_date',
  'always'
);

create type app_public.room_role as enum (
  'banned',
  'public',
  'prospect',
  'member',
  'moderator',
  'admin'
);

create table if not exists app_public.rooms (
  id uuid primary key default uuid_generate_v1mc(),
  title text,
  abstract text,
  fulltext_index_column tsvector
    constraint autogenerate_fulltext_index_column
    generated always as (
      setweight(to_tsvector('german', coalesce(title, '')), 'A') ||
      setweight(to_tsvector('german', coalesce(abstract, '')), 'B')
    ) stored,
  organization_id uuid
    default app_public.current_user_first_owned_organization_id()
    constraint organization
      references app_public.organizations (id)
      on update cascade on delete cascade,
  is_visible_for app_public.room_visibility not null default 'public',
  items_are_visible_for app_public.room_role not null default 'public',
  items_are_visible_since app_public.room_history_visibility not null default 'always',
  items_are_visible_since_date timestamptz not null default now(),
  draft_items_are_visible_for app_public.room_role,
  extend_visibility_of_items_by interval not null default '0 hours',
  is_anonymous_posting_allowed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table app_public.rooms is
  E'A room is a place where users meet. At the same time, it is a container for messages and handed-out materials.';
comment on column app_public.rooms.title is
  E'Each room has an optional title.';
comment on column app_public.rooms.abstract is
  E'Each room has an optional abstract.';
comment on constraint organization on app_public.rooms is
  E'Each room can optionally belong to an organization.';
comment on column app_public.rooms.is_visible_for is
  E'Rooms can be visible for their subscribers only (`subscribers`), to all members of the room''s organisation (`organization_members`), for all currently signed-in users (`signed_in_users`), or general in `public`.';
comment on column app_public.rooms.items_are_visible_since is 
  E'Sometimes you want to hide items of the room from users who join later. `since_subscription` allows subscribers to see items that were added *after* their subscription. Similarly, `since_invitation` allows subscribers to see items that were added *after* they had been invited to the room. `since_specified_date` allows all subscribers to see items after `items_are_visible_since_date`. Finally, `always` means that all items are visible for the room''s audience.';

create index rooms_on_title on app_public.rooms (title);
create index rooms_on_fuzzy_title on app_public.rooms using gist (title gist_trgm_ops(siglen=12));
create index rooms_on_fulltext_index_column on app_public.rooms using gin (fulltext_index_column);
create index rooms_on_organization_id on app_public.rooms (organization_id);
create index rooms_on_created_at on app_public.rooms using brin (created_at);
create index rooms_on_updated_at on app_public.rooms (updated_at);

grant select on app_public.rooms to :DATABASE_VISITOR;
grant insert (title, abstract, is_visible_for, items_are_visible_for, items_are_visible_since, is_anonymous_posting_allowed) on app_public.rooms to :DATABASE_VISITOR;
grant update (title, abstract, is_visible_for, items_are_visible_for, items_are_visible_since, is_anonymous_posting_allowed) on app_public.rooms to :DATABASE_VISITOR;
grant delete on app_public.rooms to :DATABASE_VISITOR;

alter table app_public.rooms enable row level security;

create policy select_public on app_public.rooms for select using (is_visible_for = 'public');

create policy select_if_signed_in on app_public.rooms for select using (
  is_visible_for = 'signed_in_users' 
  and app_public.current_user_id() is not null
);

create policy select_within_organization on app_public.rooms for select using (
  is_visible_for = 'organization_members' 
  and organization_id in (select app_public.current_user_member_organization_ids())
);

create policy insert_as_admin
on app_public.rooms
for insert
with check (exists (select from app_public.current_user() where is_admin));

create trigger _100_timestamps
  before insert or update on app_public.rooms
  for each row
  execute procedure app_private.tg__timestamps();

--! split: 0003-room-subscriptions.sql
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
  last_visit_at timestamptz,
  last_notification_at timestamptz,
  is_starred boolean not null default false,
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
grant insert (room_id, subscriber_id, "role", notifications, last_visit_at) on app_public.room_subscriptions to :DATABASE_VISITOR;
grant update ("role", notifications, last_visit_at) on app_public.room_subscriptions to :DATABASE_VISITOR;
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
$$ language sql stable parallel safe security definer set search_path = pg_catalog, public, pg_temp;

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
@behavior typeField +filterBy
@fieldName mySubscription
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
comment on function app_public.my_room_subscription_id(app_public.rooms) is $$
@behavior typeField +filterBy
@fieldName mySubscriptionId
$$;

create function app_public.n_room_subscriptions(room app_public.rooms, min_role app_public.room_role default 'member')
returns bigint
language sql
stable
parallel safe
as $$
  select count(*)
  from app_public.room_subscriptions
  where 
    room_id = room.id 
    and "role" >= min_role
$$;

comment on function app_public.n_room_subscriptions(room app_public.rooms, min_role app_public.room_role) is $$
@behavior typeField
@sortable
@filterable
@fieldName nSubscriptions
$$;

create or replace function app_public.has_subscriptions(room app_public.rooms, min_role app_public.room_role default 'member')
returns boolean
language sql
stable
parallel safe
security definer 
as $$
  select exists (select from app_public.room_subscriptions where "role" >= min_role and room_id = room.id)
$$;

grant execute on function app_public.has_subscriptions(room app_public.rooms, min_role app_public.room_role) to :DATABASE_VISITOR;

comment on function app_public.has_subscriptions(room app_public.rooms, min_role app_public.room_role) is $$
@behavior typeField
@filterable
$$;

-- Every subscriber should be able to see her or his rooms, even if private.
create policy show_subscribed on app_public.rooms for select using (id in (select app_public.my_subscribed_room_ids(minimum_role => 'banned')));
-- Maintainers should be able to update their rooms.
create policy manage_as_admin on app_public.rooms for all using (id in (select app_public.my_subscribed_room_ids(minimum_role => 'admin')));

alter table app_public.room_subscriptions enable row level security;
-- You should see your own room_subscriptions.
create policy manage_own on app_public.room_subscriptions for all using (subscriber_id = app_public.current_user_id());
-- You should see others in your rooms.
create policy select_peers on app_public.room_subscriptions for select using (room_id in (select app_public.my_subscribed_room_ids()));
-- You should be able to unsubscribe from your rooms.
--create policy delete_own on app_public.room_subscriptions for delete using (subscriber_id = app_public.current_user_id());
-- Maintainers can unsubscribe others from their rooms.
create policy manage_as_moderator on app_public.room_subscriptions for all using (room_id in (select app_public.my_subscribed_room_ids(minimum_role => 'moderator')));
-- You should be able to subscribe public rooms
create policy subscribe_rooms on app_public.room_subscriptions for insert with check (
  exists (
    select from app_public.rooms as r
    where 
      room_subscriptions.room_id = r.id
      and room_subscriptions.subscriber_id = app_public.current_user_id()
      and (
        -- You can become member of public rooms, or...
        (r.is_visible_for >= 'public' and room_subscriptions."role" <= 'member')
        -- prospect in private rooms.
        or (r.is_visible_for <= 'public' and room_subscriptions."role" <= 'prospect')
        -- You can take on all roles when creating a room. This is for the first admins.
        or (r.created_at = room_subscriptions.created_at)
        -- You can take on all roles in orphaned rooms.
        or (not app_public.has_subscriptions(r))
      )
  )
);

create or replace function app_hidden.verify_role_updates_on_room_subscriptions()
returns trigger
language plpgsql
as $$
declare
  me app_public.users := app_public.current_user();
  room app_public.rooms := (select r from app_public.rooms as r where id = new.room_id);
  my_subscription app_public.room_subscriptions := (select s from app_public.my_room_subscription(room) as s);
begin
  if me is null then
    raise exception 'You must log in to update subscriptions of a room' using errcode = 'LOGIN';
  end if;
  if my_subscription is null then
    raise exception 'You must be subscribed to a room to update its subscriptions.' using errcode = 'DNIED';
  end if;
  if new.subscriber_id = me.id and new.role > old.role then
    raise exception 'You cannot promote yourself.' using errcode = 'DNIED';
  end if;
  if new.subscriber_id <> me.id and new.role > my_subscription.role then
    raise exception 'You cannot promote others to a higher role than your own.' using errcode = 'DNIED';
  end if;
  if new.subscriber_id <> me.id and old.role > my_subscription.role then
    raise exception 'You cannot change the role of others if they are ranked higher than you.' using errcode = 'DNIED';
  end if;
  return new;
end
$$;

create constraint trigger t900_verify_role_updates_on_room_subscriptions
after update on app_public.room_subscriptions
for each row
when (
  new.role is distinct from old.role
  -- Does only apply along with row level security.
  and row_security_active('app_public.room_subscriptions')
)
execute function  app_hidden.verify_role_updates_on_room_subscriptions();

-- Admins should be able to add subscriptions
create policy insert_as_admin
on app_public.room_subscriptions
for insert
with check (exists (select from app_public.current_user() where is_admin));

create trigger _100_timestamps
  before insert or update on app_public.room_subscriptions
  for each row
  execute procedure app_private.tg__timestamps();

--! split: 1000-reset-topics.sql


--! split: 1001-add-topics.sql
create type app_public.topic_visibility as enum (
  'organization_members',
  'signed_in_users',
  'public'
);

create table app_public.topics (
  id uuid primary key default uuid_generate_v1mc(),
  author_id uuid
    default app_public.current_user_id()
    constraint author
      references app_public.users (id) on update cascade on delete set null,
  organization_id uuid
    default app_public.current_user_first_owned_organization_id()
    constraint organization
      references app_public.organizations (id) on update cascade on delete cascade,
  slug text
    not null
    constraint valid_slug check (slug ~ '^[\w\d-]+(/[\w\d-]+)*$'),
  title text,
  license text,
  tags text[] not null default '{}',
  is_visible_for app_public.topic_visibility not null default 'public',
  content jsonb not null,
  created_at timestamptz not null default current_timestamp,
  updated_at timestamptz not null default current_timestamp,
  constraint unique_slug_per_organization 
    unique nulls not distinct (slug, organization_id)
);

grant select on app_public.topics to :DATABASE_VISITOR;
grant insert (slug, title, content, tags, author_id, organization_id, is_visible_for, license) on app_public.topics to :DATABASE_VISITOR;
grant update (slug, title, content, tags, author_id, organization_id, is_visible_for, license) on app_public.topics to :DATABASE_VISITOR;
grant delete on app_public.topics to :DATABASE_VISITOR;

create unique index topics_have_an_unique_slug on app_public.topics (slug) where (organization_id is null);
create index topics_on_title on app_public.topics (title);
create index topics_on_author_id on app_public.topics (author_id);
create index topics_on_organization_id on app_public.topics (organization_id);
create index topics_on_tags on app_public.topics using gin (tags);
create index topics_on_content on app_public.topics using gin (content jsonb_path_ops);
create index topics_on_created_at on app_public.topics using brin (created_at);
create index topics_on_updated_at on app_public.topics (updated_at);

comment on table app_public.topics is
  E'A topic is a short text about something. Most topics should have the scope of a micro learning unit.';
comment on constraint author on app_public.topics is 
  E'Each topic has an author. The field might be null when the original author has unregistered from the application.';
comment on column app_public.topics.slug is
  E'Each topic has a slug (a name made up of lowercase letters, digits, and hypens) to be addressed with.';
comment on column app_public.topics.title is
  E'Each topic has an optional title. In case of an article, this would be the headline.';
comment on column app_public.topics.license is
  E'Each topic can optionally be licensed. Hyperlinks are allowed.';
comment on column app_public.topics.tags is
  E'Each topic can be categorized using tags.';
comment on column app_public.topics.is_visible_for is
  E'Topics can be visible to anyone (`public`), to all signed-in users (`signed_in_users`), or within an organization (`organization_members`).';
comment on column app_public.topics.content is
  E'The topics contents as JSON. Can be converted to HTML with https://tiptap.dev/api/utilities/html';


create or replace function app_hidden.tiptap_document_as_plain_text(document jsonb)
  returns text
  language sql
  immutable
  parallel safe
as $$
  select string_agg(elem#>>'{}', E'\n')
  from jsonb_path_query(
    document,
    'strict $.** ? (@.type == "text" && @.text.type() == "string").text'
  ) as elem
$$;


create or replace function app_public.topics_content_as_plain_text(topic app_public.topics)
  returns text
  language sql
  immutable
  parallel safe
as $$
  select app_hidden.tiptap_document_as_plain_text(topic.content)
$$;

alter table app_public.topics
  add column fulltext_index_column tsvector
    constraint autogenerate_fulltext_index_column
    generated always as (
      setweight(to_tsvector('german', coalesce(title, '')), 'A') ||
      setweight(to_tsvector('german', coalesce(slug, '')), 'A') ||
      setweight(to_tsvector('german', coalesce(text_array_to_string(tags, ' '), '')), 'A') ||
      setweight(to_tsvector('german', coalesce(app_hidden.tiptap_document_as_plain_text(content), '')), 'B')
    ) stored;

create index topics_on_fulltext_index_column on app_public.topics using gin (fulltext_index_column);

create or replace function app_public.topics_content_preview(topic app_public.topics, n_first_items integer default 3)
  returns jsonb
  language sql
  immutable
  parallel safe
as $$
  select jsonb_set_lax(
    topic.content,
    '{content}',
    jsonb_path_query_array(
      topic.content, 
      '$.content[0 to $min]',
      jsonb_build_object('min', coalesce(n_first_items - 1, 2))
    ),
    create_if_missing => true,
    null_value_treatment => 'use_json_null'
  )
$$;

alter table app_public.topics enable row level security;
create policy select_public on app_public.topics for select using (is_visible_for = 'public');
create policy select_if_signed_in on app_public.topics for select using (is_visible_for = 'signed_in_users' and app_public.current_user_id() is not null);
create policy select_within_organization on app_public.topics for select using (
  is_visible_for = 'organization_members' 
  and organization_id in (select app_public.current_user_member_organization_ids())
);
create policy authors_can_manage on app_public.topics for all using (author_id = app_public.current_user_id());
create policy admins_can_manage on app_public.topics for all using ((select is_admin from app_public.current_user()));

create trigger _100_timestamps
  before insert or update on app_public.topics
  for each row
  execute procedure app_private.tg__timestamps();

--! split: 2000-reset-room-messages.sql


--! split: 2001-room-messages.sql
create table app_public.room_messages (
  id uuid primary key default uuid_generate_v1mc(),
  room_id uuid not null
    constraint room
      references app_public.rooms (id)
      on update cascade on delete cascade,
  sender_id uuid
    default app_public.current_user_id()
    constraint sender
      references app_public.users (id)
      on update cascade on delete set null,
  answered_message_id uuid
    constraint answered_message
      references app_public.room_messages (id)
      on update cascade on delete restrict,
  body text,
  language text not null default 'german'
    constraint supported_language check (language in ('german', 'english', 'french')),
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  updated_at timestamptz not null default now()
);

comment on constraint answered_message on app_public.room_messages is E'@fieldName answeredMessage\n@foreignFieldName answers';
comment on constraint room on app_public.room_messages is E'@foreignFieldName messages';

create function app_public.fulltext("message" app_public.room_messages)
returns tsvector
language sql
immutable
parallel safe
as $$
  select to_tsvector(cast("message".language as regconfig), "message".body)
$$;

comment on function app_public.fulltext(app_public.room_messages) is E'@behavior typeField';

grant execute on function app_public.fulltext(app_public.room_messages) to :DATABASE_VISITOR;

create index room_messages_on_room_id on app_public.room_messages (room_id);
create index room_messages_on_sender_id on app_public.room_messages (sender_id);
create index room_messages_on_answered_message_id on app_public.room_messages (answered_message_id);
create index room_messages_on_german_fulltext on app_public.room_messages using gin ((app_public.fulltext(row(app_public.room_messages.*))));
create index room_messages_on_created_at on app_public.room_messages using brin (created_at);
create index room_messages_on_sent_at on app_public.room_messages (sent_at);
create index room_messages_on_updated_at on app_public.room_messages (updated_at);

grant select on app_public.room_messages to :DATABASE_VISITOR;
grant insert (room_id, body, sender_id, language, answered_message_id, sent_at) on app_public.room_messages to :DATABASE_VISITOR;
grant update (body, language, answered_message_id, sent_at) on app_public.room_messages to :DATABASE_VISITOR;
grant delete on app_public.room_messages to :DATABASE_VISITOR;

alter table app_public.room_messages enable row level security;

create function app_public.my_first_interaction(room app_public.rooms)
returns timestamptz
  language sql
  stable
  security definer
 set search_path = pg_catalog, public, pg_temp
as $$
  select least (
    -- my earliest sent message
    (select min(sent_at) from app_public.room_messages where room_messages.room_id = room.id),
    -- my subscription date
    (select min(created_at) from app_public.room_subscriptions where room_subscriptions.room_id = room.id and room_subscriptions.subscriber_id = app_public.current_user_id())
  )
$$;

comment on function app_public.my_first_interaction(room app_public.rooms) is $$
@behavior typeField

Date of subscription or first sent message, whatever is earlier.
$$;

grant execute on function app_public.my_first_interaction(room app_public.rooms) to :DATABASE_VISITOR;

create trigger _100_timestamps
  before insert or update on app_public.room_messages
  for each row
  execute procedure app_private.tg__timestamps();

create policy require_messages_from_current_user
on app_public.room_messages
as restrictive
for insert
to :DATABASE_VISITOR
with check (sender_id = app_public.current_user_id());

create policy only_authors_should_access_their_message_drafts
on app_public.room_messages
as restrictive
for all
to :DATABASE_VISITOR
using (sent_at is not null or sender_id = app_public.current_user_id());

create policy send_messages_to_public_rooms
on app_public.room_messages
for insert
with check (room_id in (select id from app_public.rooms where is_visible_for >= 'public'));

create policy update_own_messages
on app_public.room_messages
for update
using (sender_id = app_public.current_user_id());

create policy select_if_public_or_subscribed
on app_public.room_messages
for select
using (
  exists (
    select from app_public.rooms as r
    left join lateral app_public.my_room_subscription(r) as s on (true)
    where 
      room_messages.room_id = r.id
      and (
        -- Show all messages of rooms that I can see, if the history is public.
        r.items_are_visible_since >= 'always'
        -- Show all messages of rooms that I can see since a specified date.
        or (
          r.items_are_visible_since >= 'specified_date'
          and room_messages.created_at >= (r.items_are_visible_since_date - r.extend_visibility_of_items_by)
        )
        -- Show all messages of rooms that I subscribe, since I subscribed.
        or (
          r.items_are_visible_since >= 'subscription'
          and room_messages.created_at >= (s.created_at - r.extend_visibility_of_items_by)
        )
      )
  )
);

create policy select_my_drafts
on app_public.room_messages
for select
using (
  sent_at is null
  and sender_id = app_public.current_user_id()
);

create function app_public.send_room_message(draft_id uuid, out room_message app_public.room_messages)
  language plpgsql
  volatile
  security definer
  set search_path = pg_catalog, public, pg_temp
as $$
declare
  v_message app_public.room_messages;
  v_my_id uuid;
begin
  -- check for login
  v_my_id := app_public.current_user_id();
  if v_my_id is null then
    raise exception 'You must log to submit a draft' using errcode = 'LOGIN';
  end if;

  -- fetch message
  select * into room_message from app_public.room_messages where room_messages.id = send_room_message.draft_id and room_messages.sender_id = v_my_id;
  if not found then
    raise exception 'Could not find draft' using errcode = 'NTFND';
  end if;

  -- deny request if room message has already been sent at an ealier time.
  if room_message.sent_at is not null then
    raise exception 'message has already been sent' using errcode = 'DNIED';
  end if;

  -- mark this room message as sent
  update app_public.room_messages
    set sent_at = current_timestamp
    where room_messages.id = room_message.id
    returning * into room_message;
end
$$;

create function app_public.fetch_draft_in_room(room_id uuid)
returns app_public.room_messages
language sql
stable
parallel safe
as $$
  select * from app_public.room_messages
  where
    room_messages.room_id = fetch_draft_in_room.room_id
    and sent_at is null
    and sender_id = app_public.current_user_id()
$$;

create function app_public.latest_message(room app_public.rooms)
returns app_public.room_messages
language sql
stable
parallel safe
as $$
  select *
  from app_public.room_messages
  where
    room_id = room.id
    and sent_at is not null
  order by sent_at desc
  limit 1
$$;

grant execute on function app_public.latest_message(app_public.rooms) to :DATABASE_VISITOR;
comment on function app_public.latest_message(app_public.rooms) is E'@behavior typeField';


create table if not exists app_public.room_message_attachments (
  id uuid primary key default uuid_generate_v1mc(),
  room_message_id uuid not null
    constraint room_message references app_public.room_messages (id)
    on update cascade on delete cascade,
  topic_id uuid not null
    constraint topic references app_public.topics (id)
    on update cascade on delete cascade,
  created_at timestamptz not null default now(),
  constraint unique_powerup_exercises_per_room_message_id
    unique (topic_id, room_message_id)
);

comment on constraint room_message on app_public.room_message_attachments is
  E'@fieldName message\n@foreignFieldName attachments';

create index room_message_attachments_on_room_message_id on app_public.room_message_attachments (room_message_id);
create index room_message_attachments_on_topic_id on app_public.room_message_attachments (topic_id);
create index room_message_attachments_on_created_at on app_public.room_message_attachments using brin (created_at);

grant select on app_public.room_message_attachments to :DATABASE_VISITOR;
grant insert (id, room_message_id, topic_id) on app_public.room_message_attachments to :DATABASE_VISITOR;
grant delete on app_public.room_message_attachments to :DATABASE_VISITOR;

alter table app_public.room_message_attachments enable row level security;

create policy select_attachments 
on app_public.room_message_attachments
for select
using (
  -- Show attachments for all messages that I can see.
  exists (
    select from app_public.room_messages as m
    where room_message_attachments.room_message_id = m.id
  )
);

create policy add_attachments 
on app_public.room_message_attachments
for insert
with check (
  exists (
    select from app_public.room_messages as m
    where 
      room_message_attachments.room_message_id = m.id
      and m.sender_id = app_public.current_user_id()
  )
);

create policy delete_attachments
on app_public.room_message_attachments
for delete
using (
  exists (
    select from app_public.room_messages as m
    where 
      room_message_attachments.room_message_id = m.id
      and m.sender_id = app_public.current_user_id()
  )
);

--! split: 3000-add-room-items.sql
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


create function app_public.latest_activity_at(room app_public.rooms)
returns timestamptz
language sql
stable
parallel safe
as $$
  select greatest(
    room.created_at,
    room.updated_at,
    (select greatest(max(ri.contributed_at), max(ri.updated_at)) from app_public.room_items as ri where ri.room_id = room.id) 
  )
$$;

grant execute on function app_public.latest_activity_at(app_public.rooms) to :DATABASE_VISITOR;
comment on function app_public.latest_activity_at(app_public.rooms) is E'@behavior typeField +orderBy +filterBy';


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

--! split: 5000-files.sql
create table app_public.files (
  id uuid primary key default uuid_generate_v1mc(),
  contributor_id uuid
    default app_public.current_user_id()
    constraint contributor
      references app_public.users (id)
      on update cascade on delete set null,
  uploaded_bytes int,
  total_bytes int,
  "filename" text,
  path_on_storage text,
  mime_type text,
  sha256 text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

grant select on app_public.files to :DATABASE_VISITOR;
grant insert (id, contributor_id, uploaded_bytes, total_bytes, "filename", mime_type) on app_public.files to :DATABASE_VISITOR;
grant update (id, uploaded_bytes, total_bytes, "filename", mime_type) on app_public.files to :DATABASE_VISITOR;
grant delete on app_public.files to :DATABASE_VISITOR;

create trigger _100_timestamps
  before insert or update on app_public.files
  for each row
  execute procedure app_private.tg__timestamps();

--! split: 6000-documents.sql
create table if not exists app_public.pdf_files (
  id uuid not null
    primary key
    constraint "file"
      references app_public.files (id)
      on update cascade on delete cascade,
  title text,
  pages smallint not null,
  metadata jsonb,
  content_as_plain_text text,
  fulltext_index_column tsvector
    constraint autogenerate_fulltext_index_column
    generated always as (to_tsvector('german', content_as_plain_text)) stored,
  thumbnail_id uuid
    constraint thumbnail
      references app_public.files (id)
      on update cascade on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

grant select on app_public.pdf_files to :DATABASE_VISITOR;
grant insert (id, title, pages, metadata, content_as_plain_text, thumbnail_id) on app_public.pdf_files to :DATABASE_VISITOR;
grant update (id, title, pages, metadata, content_as_plain_text, thumbnail_id) on app_public.pdf_files to :DATABASE_VISITOR;
grant delete on app_public.pdf_files to :DATABASE_VISITOR;


create trigger _100_timestamps
  before insert or update on app_public.pdf_files
  for each row
  execute procedure app_private.tg__timestamps();

--! split: 7000-room-item-attachments.sql
create type app_public.room_item_attachment_type as enum ('TOPIC', 'FILE');

grant usage on type app_public.room_item_attachment_type to :DATABASE_VISITOR;

create table app_public.room_item_attachments (
  id uuid primary key default uuid_generate_v1mc(),
  room_item_id uuid not null
    constraint room_item
      references app_public.room_items (id)
      on update cascade on delete cascade,
  topic_id uuid
    constraint topic
      references app_public.topics (id)
      on update cascade on delete restrict,
  file_id uuid
    constraint "file"
      references app_public.files (id)
      on update cascade on delete restrict,
  created_at timestamptz not null default now(),
  constraint either_topic_or_file 
    check (num_nonnulls(topic_id, file_id) = 1)
);

grant select on app_public.room_item_attachments to :DATABASE_VISITOR;
grant insert (id, room_item_id, topic_id, file_id) on app_public.room_item_attachments to :DATABASE_VISITOR;
grant delete on app_public.room_item_attachments to :DATABASE_VISITOR;

create index room_item_attachments_on_room_item_id on app_public.room_item_attachments (room_item_id);
create index room_item_attachments_on_topic_id on app_public.room_item_attachments (topic_id);
create index room_item_attachments_on_file_id on app_public.room_item_attachments (file_id);
create index room_item_attachments_on_created_at on app_public.room_item_attachments using brin (created_at);

--! split: 9000-fulltext-search.sql
create extension if not exists pg_trgm with schema public;

drop type if exists 
  app_public.textsearchable_entity, 
  app_public.textsearch_match cascade;

create type app_public.textsearchable_entity as enum ('user', 'topic', 'room', 'document', 'file');

create type app_public.textsearch_match as (
  id uuid,
  "type" app_public.textsearchable_entity,
  title text,
  snippet text,
  rank_or_similarity float4,
  "user_id" uuid,
  topic_id uuid,
  room_id uuid
);

grant usage on type app_public.textsearch_match, app_public.textsearchable_entity to :DATABASE_VISITOR;

comment on column app_public.textsearch_match."type" is
  E'@notNull\n@behavior +filterBy';
comment on column app_public.textsearch_match.title is
  E'@notNull\n@behavior +orderBy +filterBy';
comment on column app_public.textsearch_match.rank_or_similarity is
  E'@notNull\n@behavior +orderBy +filterBy';

comment on type app_public.textsearch_match is $$
@primaryKey id
@foreignKey (user_id) references app_public.users (id)|@fieldName user
@foreignKey (topic_id) references app_public.topics (id)|@fieldName topic
@foreignKey (room_id) references app_public.rooms (id)|@fieldName room
$$;

create index if not exists users_on_fuzzy_username on app_public.users using gist (username gist_trgm_ops(siglen=12));

create or replace function app_public.global_search(
  term text, 
  entities app_public.textsearchable_entity[] default '{user,topic}'
)
  returns setof app_public.textsearch_match
  language sql
  stable
  parallel safe
  rows 10
as $$
  -- fetch users
  select
    id,
    'user'::app_public.textsearchable_entity as "type",
    username as title,
    null as snippet,
    word_similarity(term, username) as rank_or_similarity,
    id as "user_id",
    null::uuid as topic_id,
    null::uuid as room_id
  from app_public.users
  where
    'user' = any (entities)
    and term <% username
  -- fetch topics
  union all
  select 
    id,
    'topic'::app_public.textsearchable_entity as "type",
    coalesce(title, slug, 'Thema ' || id) as title,
    ts_headline('german', app_hidden.tiptap_document_as_plain_text(topics.content), query) as snippet,
    ts_rank_cd(array[0.3, 0.5, 0.8, 1.0], fulltext_index_column, query, 32 /* normalization to [0..1) by rank / (rank+1) */) as rank_or_similarity,
    null::uuid as "user_id",
    id as topic_id,
    null::uuid as room_id
  from 
    app_public.topics,
    websearch_to_tsquery('german', term) as query
  where
    'topic' = any (entities)
    and query @@ fulltext_index_column
  -- fetch rooms
  union all
  select
    id,
    'room'::app_public.textsearchable_entity as "type",
    coalesce(title, 'Raum ' || id) as title,
    abstract as snippet,
    greatest (
      word_similarity(term, title),
      ts_rank_cd(array[0.3, 0.5, 0.8, 1.0], fulltext_index_column, query, 32 /* normalization to [0..1) by rank / (rank+1) */)
    ) as rank_or_similarity,
    null::uuid as "user_id",
    null::uuid as topic_id,
    id as room_id
  from 
    app_public.rooms,
    websearch_to_tsquery('german', term) as query
  where 
    'room' = any (entities)
    and (query @@ fulltext_index_column or term <% title)
  -- order the union
  order by rank_or_similarity desc
$$;

grant execute on function app_public.global_search(text,app_public.textsearchable_entity[]) to :DATABASE_VISITOR;

comment on function app_public.global_search(text,app_public.textsearchable_entity[]) is $$
@filterable
@sortable
$$;
