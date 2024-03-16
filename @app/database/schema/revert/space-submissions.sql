-- Revert 0814-cms:space-submissions from pg

BEGIN;

drop table if exists app_public.space_submissions;

COMMIT;
