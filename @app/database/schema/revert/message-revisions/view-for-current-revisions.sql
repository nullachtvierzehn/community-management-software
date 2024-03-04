-- Revert 0814-cms:message-revisions/view-for-current-revisions from pg

BEGIN;

drop view app_public.current_message_revisions;

COMMIT;
