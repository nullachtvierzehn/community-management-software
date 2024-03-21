-- Revert 0814-cms:space-items/policies/select-submitted from pg

BEGIN;

drop policy select_submitted on app_public.space_items;

COMMIT;
