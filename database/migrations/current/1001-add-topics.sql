create type app_public.topic_visibility as enum (
  'within_organization',
  'if_signed_in',
  'public'
);

create table app_public.topics (
  id uuid primary key default uuid_generate_v1mc(),
  slug text
    not null
    constraint topics_have_an_unique_slug unique
    constraint valid_slug check (slug ~ '^[\w\d-]+(/[\w\d-]+)*$'),
  author_id uuid
    default app_public.current_user_id()
    constraint author
      references app_public.users (id) on update cascade on delete set null,
  organization_id uuid
    default app_public.current_user_first_organization_id()
    constraint organization
      references app_public.organizations (id) on update cascade on delete cascade,
  title text,
  license text,
  tags text[] not null default '{}',
  visibility app_public.topic_visibility not null default 'public',
  content jsonb not null,
  created_at timestamptz not null default current_timestamp,
  updated_at timestamptz not null default current_timestamp
);


comment on table app_public.topics is
  E'A topic is a short text about something. Most topics should have the scope of a micro learning unit.';
comment on column app_public.topics.slug is
  E'Each topic has a slug (a name made up of lowercase letters, digits, and hypens) to be addressed with.';
comment on column app_public.topics.content is
  E'The topics contents as JSON. Can be converted to HTML with https://tiptap.dev/api/utilities/html';

create index topics_on_title on app_public.topics (title);
create index topics_on_author_id on app_public.topics (author_id);
create index topics_on_organization_id on app_public.topics (organization_id);
create index topics_on_tags on app_public.topics using gin (tags);
create index topics_on_content on app_public.topics using gin (content jsonb_path_ops);
create index topics_on_created_at on app_public.topics using brin (created_at);
create index topics_on_updated_at on app_public.topics (updated_at);

grant select on app_public.topics to :DATABASE_VISITOR;
grant insert (slug, title, content, author_id, organization_id, visibility, license) on app_public.topics to :DATABASE_VISITOR;
grant update (slug, title, content, author_id, organization_id, visibility, license) on app_public.topics to :DATABASE_VISITOR;
grant delete on app_public.topics to :DATABASE_VISITOR;

alter table app_public.topics enable row level security;
create policy select_public on app_public.topics for select using (visibility = 'public');
create policy authors_can_manage on app_public.topics for all using (author_id = app_public.current_user_id());
create policy admins_can_manage on app_public.topics for all using ((select is_admin from app_public.current_user()));

create trigger _100_timestamps
  before insert or update on app_public.topics
  for each row
  execute procedure app_private.tg__timestamps();