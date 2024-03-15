-- Deploy 0814-cms:space-submissions to pg
-- requires: spaces
-- requires: message-revisions
-- requires: initial

BEGIN;

create table app_public.space_items (
  id uuid primary key default uuid_generate_v1mc(),
  space_id uuid not null 
    constraint "space"
    references app_public.spaces(id) 
    on update cascade on delete cascade,
  submitter_id uuid 
    default app_public.current_user_id()
    constraint submitter
      references app_public.users (id)
      on update cascade on delete cascade,
  message_id uuid not null,
  revision_id uuid not null,
  constraint message_revision
    foreign key (message_id, revision_id)
    references app_public.message_revisions (id, revision_id)
    on update cascade on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table app_public.space_items enable row level security;

grant select on app_public.space_items to "$DATABASE_VISITOR";
grant insert (id, space_id, submitter_id, message_id, revision_id) on app_public.space_items to "$DATABASE_VISITOR";
grant update (revision_id) on app_public.space_items to "$DATABASE_VISITOR";
grant delete on app_public.space_items to "$DATABASE_VISITOR";

create index space_items_on_submitter_id on app_public.space_items (submitter_id);
create index space_items_on_space_id on app_public.space_items (space_id);
create index space_items_on_message_id_revision_id on app_public.space_items (message_id, revision_id);
create index space_items_on_created_at on app_public.space_items using brin (created_at);
create index space_items_on_updated_at on app_public.space_items (updated_at);

-- auto-update updated_at
create trigger _100_timestamps
  before insert or update on app_public.space_items
  for each row
  execute procedure app_private.tg__timestamps();

COMMIT;
