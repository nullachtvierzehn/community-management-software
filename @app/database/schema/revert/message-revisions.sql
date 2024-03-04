-- Revert 0814-cms:message-revisions from pg

BEGIN;

drop table app_public.message_revisions;

COMMIT;
