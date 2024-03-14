-- Revert 0814-cms:spaces/policies/select-public-spaces from pg

BEGIN;

drop policy can_select_if_public on app_public.spaces;

COMMIT;
