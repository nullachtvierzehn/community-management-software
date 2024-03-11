-- Revert 0814-cms:spaces/policies/can-select-if-newly-created from pg

BEGIN;

drop policy can_select_if_newly_created
  on app_public.spaces;

COMMIT;
