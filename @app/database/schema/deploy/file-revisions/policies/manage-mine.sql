-- Deploy 0814-cms:file-revisions/policies/manage-mine to pg
-- requires: file-revisions

BEGIN;

create policy manage_mine
on app_public.file_revisions
for all
to "$DATABASE_VISITOR"
using (editor_id = app_public.current_user_id());

COMMIT;
