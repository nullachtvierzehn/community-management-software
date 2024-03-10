-- Revert 0814-cms:space-subscriptions from pg

BEGIN;

drop table app_public.space_subscriptions;

COMMIT;
