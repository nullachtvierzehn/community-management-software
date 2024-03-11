-- Revert 0814-cms:space-subscriptions/my-space-subscriptions from pg

BEGIN;

drop function app_public.my_space_subscription_ids();

COMMIT;
