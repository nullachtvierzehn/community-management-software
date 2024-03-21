-- Deploy 0814-cms:pdf-file-revisions to pg
-- requires: file-revisions

BEGIN;

create table app_public.pdf_file_revisions (
  id uuid not null,
  revision_id uuid not null,
  constraint pdf_file_revisions_pk
    primary key (id, revision_id),
  constraint file_revision
    foreign key (id, revision_id)
    references app_public.file_revisions (id, revision_id)
    on update cascade on delete cascade,
  title text,
  pages smallint not null,
  metadata jsonb,
  content_as_plain_text text,
  fulltext_index_column tsvector
    constraint autogenerate_fulltext_index_column
    generated always as (to_tsvector('german', content_as_plain_text)) stored,
  thumbnail_id uuid,
  thumbnail_revision_id uuid,
    constraint thumbnail
      foreign key (thumbnail_id, thumbnail_revision_id)
      references app_public.file_revisions (id, revision_id) match full
      on update cascade on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table app_public.pdf_file_revisions is $$
  @omit all
  $$;

grant select on app_public.pdf_file_revisions to "$DATABASE_VISITOR";
--grant insert (id, revision_id, title, pages, metadata, content_as_plain_text, thumbnail_id) on app_public.pdf_file_revisions to :DATABASE_VISITOR;
--grant update (title, pages, metadata, content_as_plain_text, thumbnail_id) on app_public.pdf_file_revisions to :DATABASE_VISITOR;
--grant delete on app_public.pdf_file_revisions to :DATABASE_VISITOR;

create trigger _100_timestamps
  before insert or update on app_public.pdf_file_revisions
  for each row
  execute procedure app_private.tg__timestamps();

COMMIT;
