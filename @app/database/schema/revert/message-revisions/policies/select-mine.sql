-- Revert 0814-cms:message-revisions/policies/select-mine from pg

BEGIN;

drop policy select_mine
  on app_public.message_revisions;

COMMIT;
