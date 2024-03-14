-- Revert 0814-cms:spaces/my-space-ids from pg

BEGIN;

drop function app_public.my_space_ids(app_public.ability[], app_public.ability[]);

COMMIT;
