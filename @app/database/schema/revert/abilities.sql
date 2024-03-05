-- Revert 0814-cms:abilities from pg

BEGIN;

drop type app_public.ability;

COMMIT;
