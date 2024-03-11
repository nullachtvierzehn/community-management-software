-- Revert 0814-cms:space-subscriptions/policies/can-delete-my-subscriptions from pg

BEGIN;

drop policy can_delete_my_subscriptions
  on app_public.space_subscriptions;

COMMIT;
