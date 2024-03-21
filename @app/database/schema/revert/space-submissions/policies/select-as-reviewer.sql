-- Revert 0814-cms:space-submissions/policies/select-as-reviewer from pg

BEGIN;

drop policy select_as_reviewer on app_public.space_submissions;

COMMIT;
