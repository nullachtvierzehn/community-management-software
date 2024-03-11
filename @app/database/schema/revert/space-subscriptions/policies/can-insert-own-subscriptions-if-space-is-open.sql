-- Revert 0814-cms:space-subscriptions/policies/can-insert-own-subscriptions-if-space-is-open from pg

BEGIN;

drop policy can_insert_own_subscriptions_if_space_is_open
  on app_public.space_subscriptions;

COMMIT;
