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