-- Revert 0814-cms:space-submissions/policies/can-insert-own-items from pg

BEGIN;

drop policy can_insert_own_items
  on app_public.space_submissions;

COMMIT;
