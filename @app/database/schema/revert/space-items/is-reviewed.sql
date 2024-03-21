-- Revert 0814-cms:space-items/is-reviewed from pg

BEGIN;

drop function app_public.space_items_is_reviewed(i app_public.space_items);

COMMIT;
