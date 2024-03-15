-- Revert 0814-cms:space-submissions from pg

BEGIN;

drop table app_public.space_items;

COMMIT;
