-- Revert 0814-cms:spaces/policies/can-manage-depending-on-abilities from pg

BEGIN;

drop policy can_manage_with_matching_abilities
  on app_public.spaces;

COMMIT;
