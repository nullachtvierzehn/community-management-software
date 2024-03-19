-- Deploy 0814-cms:file-revisions to pg
-- requires: initial

BEGIN;

create table app_public.file_revisions(
  -- two-column primary key with id and revision_id
  id uuid not null
    default uuid_generate_v1mc(),
  revision_id uuid not null
    default uuid_generate_v1mc(),
  constraint file_revisions_pk
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
  update_comment text,

  -- body
  uploaded_bytes int,
  total_bytes int,
  "filename" text,
  path_on_storage text,
  mime_type text,
  sha256 text
);

alter table app_public.file_revisions enable row level security;

grant select on app_public.file_revisions to "$DATABASE_VISITOR";
grant insert (id, revision_id, parent_revision_id, uploaded_bytes, total_bytes, "filename", mime_type) on app_public.file_revisions to "$DATABASE_VISITOR";
grant update (uploaded_bytes, total_bytes, "filename", mime_type) on app_public.file_revisions to "$DATABASE_VISITOR";
grant delete on app_public.file_revisions to "$DATABASE_VISITOR";

create trigger _100_timestamps
  before insert or update on app_public.file_revisions
  for each row
  execute procedure app_private.tg__timestamps();

COMMIT;
