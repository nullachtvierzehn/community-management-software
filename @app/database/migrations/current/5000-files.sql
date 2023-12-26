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