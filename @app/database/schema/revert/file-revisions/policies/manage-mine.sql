-- Revert 0814-cms:file-revisions/policies/manage-mine from pg

BEGIN;

drop policy manage_mine
  on app_public.file_revisions;

COMMIT;
