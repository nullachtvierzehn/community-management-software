-- Revert 0814-cms:message-revisions/update-active-or-current-revisions-using-a-trigger from pg

BEGIN;

drop trigger _500_update_active_message_revision on app_public.active_message_revisions;

drop trigger _500_update_current_message_revision on app_public.current_message_revisions;

drop function app_hidden.update_active_or_current_message_revision();

COMMIT;
