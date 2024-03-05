-- Revert 0814-cms:spaces from pg

BEGIN;

drop table app_public.spaces;

COMMIT;
