-- Deploy 0814-cms:message-revisions to pg
-- requires: initial

BEGIN;

create table app_public.message_revisions (
  -- two-column primary key with id and revision_id
  id uuid not null
    default uuid_generate_v1mc(),
  revision_id uuid not null 
    default uuid_generate_v1mc(),
  constraint message_revisions_pk
    primary key (id, revision_id),

  -- refer to parent revisions
  parent_revision_id uuid,
  constraint parent_revision
    foreign key (id, parent_revision_id)
    references app_public.message_revisions (id, revision_id)
    on update cascade on delete set null,
  
  -- editing user, might be different, depending on revision.
  editor_id uuid 
    default app_public.current_user_id()
    constraint editor
      references app_public.users (id)
      on update cascade on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- body
  "subject" text,
  body jsonb
);

alter table app_public.message_revisions enable row level security;

comment on constraint parent_revision on app_public.message_revisions is $$
  @fieldName parentRevision
  @foreignFieldName childRevisions
  $$;

create index message_revisions_on_revision_id on app_public.message_revisions (revision_id);
create index message_revisions_on_parent_revision_id on app_public.message_revisions (parent_revision_id);
create index message_revisions_on_editor_id on app_public.message_revisions (editor_id);
create index message_revisions_on_created_at on app_public.message_revisions using brin (created_at);
create index message_revisions_on_updated_at on app_public.message_revisions using brin (updated_at);

grant select on app_public.message_revisions to "$DATABASE_VISITOR";
grant update ("subject", body) on app_public.message_revisions to "$DATABASE_VISITOR";
grant insert (id, parent_revision_id, editor_id, "subject", body) on app_public.message_revisions to "$DATABASE_VISITOR";
grant delete on app_public.message_revisions to "$DATABASE_VISITOR";

-- auto-update updated_at
create trigger _100_timestamps
  before insert or update on app_public.message_revisions
  for each row
  execute procedure app_private.tg__timestamps();

COMMIT;
