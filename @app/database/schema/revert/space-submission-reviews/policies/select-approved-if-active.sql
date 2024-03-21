-- Revert 0814-cms:space-submission-reviews/policies/select-approved-if-active from pg

BEGIN;

drop policy select_approved on app_public.space_submission_reviews;

COMMIT;
