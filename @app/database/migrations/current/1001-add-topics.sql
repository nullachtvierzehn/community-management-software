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

create unique index topics_have_an_unique_slug on app_public.topics (slug) where (organization_id is null);
create index topics_on_title on app_public.topics (title);
create index topics_on_author_id on app_public.topics (author_id);
create index topics_on_organization_id on app_public.topics (organization_id);
create index topics_on_tags on app_public.topics using gin (tags);
create index topics_on_content on app_public.topics using gin (content jsonb_path_ops);
create index topics_on_created_at on app_public.topics using brin (created_at);
create index topics_on_updated_at on app_public.topics (updated_at);

grant select on app_public.topics to :DATABASE_VISITOR;
grant insert (slug, title, content, author_id, organization_id, is_visible_for, license) on app_public.topics to :DATABASE_VISITOR;
grant update (slug, title, content, author_id, organization_id, is_visible_for, license) on app_public.topics to :DATABASE_VISITOR;
grant delete on app_public.topics to :DATABASE_VISITOR;

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