-- Revert 0814-cms:space-items/latest-active-submission from pg

BEGIN;

drop function app_public.latest_active_submission(i app_public.space_items);

COMMIT;
