-- Revert 0814-cms:file-revisions from pg

BEGIN;

drop table app_public.file_revisions;

COMMIT;
