-- Deploy 0814-cms:message-revisions/policies/manage-mine to pg
-- requires: message-revisions

BEGIN;

create policy manage_mine
  on app_public.message_revisions
  for all
  to "$DATABASE_VISITOR"
  using (editor_id = app_public.current_user_id());

COMMIT;
