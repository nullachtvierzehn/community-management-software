-- Revert 0814-cms:space-submissions/policies/select-approved from pg

BEGIN;

drop policy select_approved
on app_public.space_submissions;

COMMIT;
