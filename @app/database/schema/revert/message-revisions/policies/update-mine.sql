-- Revert 0814-cms:message-revisions/policies/update-mine from pg

BEGIN;

drop policy update_mine
  on app_public.message_revisions;

COMMIT;
