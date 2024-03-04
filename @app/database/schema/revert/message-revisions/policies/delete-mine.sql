-- Revert 0814-cms:message-revisions/policies/delete-mine from pg

BEGIN;

drop policy delete_mine
  on app_public.message_revisions;

COMMIT;
