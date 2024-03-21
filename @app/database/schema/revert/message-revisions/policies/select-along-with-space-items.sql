-- Revert 0814-cms:message-revisions/policies/select-along-with-space-items from pg

BEGIN;

drop policy select_along_with_space_items
on app_public.message_revisions;

COMMIT;
