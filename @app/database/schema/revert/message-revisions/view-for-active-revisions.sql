-- Revert 0814-cms:message-revisions/view-for-active-revisions from pg

BEGIN;

drop view app_public.active_message_revisions;

COMMIT;
