-- Revert 0814-cms:space-items/policies/delete-own from pg

BEGIN;

drop policy delete_own on app_public.space_items;

COMMIT;
