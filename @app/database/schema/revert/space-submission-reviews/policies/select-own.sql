-- Revert 0814-cms:space-submission-reviews/policies/select-own from pg

BEGIN;

drop policy if exists select_own
  on app_public.space_submission_reviews;

COMMIT;
