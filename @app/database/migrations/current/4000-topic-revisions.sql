create table app_public.topic_revisions (
  -- two-column primary key with id and revision_id
  id uuid not null 
    default uuid_generate_v1mc(),
  revision_id uuid not null 
    default uuid_generate_v1mc(),
  constraint topic_revisions_pk
    primary key (id, revision_id),

  -- refer to parent revisions
  parent_revision_id uuid,
  constraint parent_revision
    foreign key (parent_revision_id, id)
    references app_public.topic_revisions (revision_id, id)
    on update cascade on delete cascade
    deferrable initially immediate,
  
  -- editing user, might be different, depending on revision.
  editor_id uuid 
    default app_public.current_user_id()
    constraint editor
      references app_public.users (id)
      on update cascade on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- features of topic
  title text,
  license text,
  tags text[] not null default '{}',
  content jsonb not null
);

comment on table app_public.topic_revisions is 
  E'@implements SubmittableEntity';

comment on constraint parent_revision on app_public.topic_revisions is $$
  @fieldName parentRevision
  @foreignFieldName childRevisions
  $$;

grant select on app_public.topic_revisions to :DATABASE_VISITOR;
grant insert (id, parent_revision_id, editor_id, title, license, tags, content) on app_public.topic_revisions to :DATABASE_VISITOR;
grant delete on app_public.topic_revisions to :DATABASE_VISITOR;

create index topic_revisions_on_title on app_public.topic_revisions (title);
create index topic_revisions_on_editor_id on app_public.topic_revisions (editor_id);
create index topic_revisions_on_tags on app_public.topic_revisions using gin (tags);
create index topic_revisions_on_content on app_public.topic_revisions using gin (content jsonb_path_ops);
create index topic_revisions_on_created_at on app_public.topic_revisions using brin (created_at);

create trigger _100_timestamps
  before insert or update on app_public.topic_revisions
  for each row
  execute procedure app_private.tg__timestamps();


comment on table app_public.topic_revisions is
  E'A topic is a short text about something. Most topics should have the scope of a micro learning unit.';
comment on constraint editor on app_public.topic_revisions is 
  E'Each topic has an editor. The field might be null when the editor has unregistered from the application.';
comment on column app_public.topic_revisions.title is
  E'Each topic has an optional title. In case of an article, this would be the headline.';
comment on column app_public.topic_revisions.license is
  E'Each topic can optionally be licensed. Hyperlinks are allowed.';
comment on column app_public.topic_revisions.tags is
  E'Each topic can be categorized using tags.';
comment on column app_public.topic_revisions.content is
  E'The topics contents as JSON. Can be converted to HTML with https://tiptap.dev/api/utilities/html';
