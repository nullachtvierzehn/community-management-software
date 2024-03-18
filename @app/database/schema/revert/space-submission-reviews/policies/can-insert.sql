-- Revert 0814-cms:space-submission-reviews/policies/can-insert from pg

BEGIN;

drop policy if exists can_insert on app_public.space_submission_reviews;
drop policy if exists can_insert_own_items on app_public.space_submission_reviews;

COMMIT;
