-- Revert 0814-cms:space-submission-reviews from pg

BEGIN;

drop table if exists app_public.space_submission_reviews;

drop type if exists app_public.review_result;

COMMIT;
