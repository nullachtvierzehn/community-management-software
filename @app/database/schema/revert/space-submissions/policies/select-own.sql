-- Revert 0814-cms:space-submissions/policies/select-own from pg

BEGIN;

drop policy select_own
on app_public.space_submissions;

COMMIT;
