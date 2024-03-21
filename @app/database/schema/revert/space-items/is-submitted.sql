-- Revert 0814-cms:space-items/is-submitted from pg

BEGIN;

drop function app_public.space_items_is_submitted(i app_public.space_items);

COMMIT;
