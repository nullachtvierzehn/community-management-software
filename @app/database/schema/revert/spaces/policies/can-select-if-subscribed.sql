-- Revert 0814-cms:spaces/policies/can-select-if-subscribed from pg

BEGIN;

drop policy can_select_if_subscribed
  on app_public.spaces;

COMMIT;
