-- Revert 0814-cms:message-revisions/policies/manage-mine from pg

BEGIN;

drop policy manage_mine
  on app_public.message_revisions;

COMMIT;
