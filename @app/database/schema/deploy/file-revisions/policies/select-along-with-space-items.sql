-- Deploy 0814-cms:file-revisions/policies/select-along-with-space-items to pg
-- requires: space-items
-- requires: file-revisions

BEGIN;

create policy select_along_with_space_items
on app_public.file_revisions
for select
to "$DATABASE_VISITOR"
using ((id, revision_id) in (select file_id, revision_id from app_public.space_items));

COMMIT;
