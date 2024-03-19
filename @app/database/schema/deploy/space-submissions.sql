-- Deploy 0814-cms:space-submissions to pg
-- requires: space-items

BEGIN;

create table app_public.space_submissions (
  id uuid primary key default uuid_generate_v1mc(),
  space_item_id uuid not null
    constraint space_item
    references app_public.space_items (id)
    on update cascade on delete cascade,
  submitter_id uuid
    default app_public.current_user_id()
    constraint submitter
    references app_public.users(id)
    on update cascade on delete cascade,
  message_id uuid,
  file_id uuid,
  revision_id uuid not null,
  constraint ensure_non_overlapping_types
    check (num_nonnulls(message_id, file_id) = 1),
  constraint message_revision
    foreign key (message_id, revision_id)
      references app_public.message_revisions (id, revision_id)
      on update cascade on delete cascade,
  constraint file_revision
    foreign key (file_id, revision_id)
    references app_public.file_revisions (id, revision_id)
    on update cascade on delete cascade,
  submitted_at timestamptz not null default now()
);

comment on constraint space_item on app_public.space_submissions
  is E'@foreignFieldName submissions';

alter table app_public.space_submissions enable row level security;

grant select on app_public.space_submissions to "$DATABASE_VISITOR";
grant insert (id, space_item_id, submitter_id, message_id, revision_id) on app_public.space_submissions to "$DATABASE_VISITOR";
grant delete on app_public.space_submissions to "$DATABASE_VISITOR";

create index space_submissions_on_editor_id on app_public.space_submissions (submitter_id);
create index space_submissions_on_space_item_id on app_public.space_submissions (space_item_id);
create index space_submissions_on_message_id_revision_id on app_public.space_submissions (message_id, revision_id);
create index space_submissions_on_file_id_revision_id on app_public.space_submissions (file_id, revision_id);
create index space_submissions_on_created_at on app_public.space_submissions using brin (submitted_at);

COMMIT;
