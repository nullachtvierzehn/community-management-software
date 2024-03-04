-- Verify 0814-cms:message-revisions/policies/insert-mine-if-active on pg

BEGIN;

drop policy insert_mine_if_active
  on app_public.message_revisions;

ROLLBACK;
