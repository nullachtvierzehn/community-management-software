-- Revert 0814-cms:space-items/view-for-submissions-and-reviews from pg

BEGIN;

drop view app_hidden.space_item_submissions_and_reviews;

COMMIT;
