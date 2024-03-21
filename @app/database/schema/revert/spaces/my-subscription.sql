-- Revert 0814-cms:spaces/my-subscription from pg

BEGIN;

drop function app_public.my_subscription(s app_public.spaces);

COMMIT;
