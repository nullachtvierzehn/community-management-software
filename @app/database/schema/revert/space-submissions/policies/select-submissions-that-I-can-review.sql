-- Revert 0814-cms:space-submissions/policies/select-submissions-that-I-can-review from pg

BEGIN;

drop policy select_submissions_that_I_can_review
  on app_public.space_submissions;

COMMIT;
