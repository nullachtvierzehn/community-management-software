-- Revert 0814-cms:pdf-file-revisions from pg

BEGIN;

drop table app_public.pdf_file_revisions;

COMMIT;
