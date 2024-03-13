-- Revert 0814-cms:space-subscriptions/policies/can-update-my-own-policies from pg

BEGIN;

drop policy can_update_my_subscriptions
  on app_public.space_subscriptions;

COMMIT;
