-- Revert 0814-cms:message-revisions/rebase-message-revisions-before-deletion from pg

BEGIN;

drop trigger _200_rebase_message_revisions_before_deletion on app_public.message_revisions;

drop function app_hidden.rebase_message_revisions_before_deletion();

COMMIT;
