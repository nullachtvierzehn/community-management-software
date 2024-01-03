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
grant insert (title, abstract, is_visible_for, items_are_visible_since, is_anonymous_posting_allowed) on app_public.rooms to :DATABASE_VISITOR;
grant update (title, abstract, is_visible_for, items_are_visible_since, is_anonymous_posting_allowed) on app_public.rooms to :DATABASE_VISITOR;
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