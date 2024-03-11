-- Revert 0814-cms:space-subscriptions/policies/can-select-my-subscriptions from pg

BEGIN;

drop policy can_select_my_subscriptions
  on app_public.space_subscriptions;

COMMIT;
