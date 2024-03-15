-- Revert 0814-cms:space-items/policies/can-insert-with-proper-abilities from pg

BEGIN;

drop policy can_create_with_proper_abilities
  on app_public.space_items;

COMMIT;
