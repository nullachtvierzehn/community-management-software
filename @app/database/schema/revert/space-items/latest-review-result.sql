-- Revert 0814-cms:space-items/latest-review-result from pg

BEGIN;

drop function app_public.space_items_latest_review_result(i app_public.space_items);

COMMIT;
