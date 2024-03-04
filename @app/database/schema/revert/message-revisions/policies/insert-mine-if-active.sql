-- Revert 0814-cms:message-revisions/policies/insert-mine-if-active from pg

BEGIN;

drop policy insert_mine_if_active on app_public.message_revisions;

COMMIT;
