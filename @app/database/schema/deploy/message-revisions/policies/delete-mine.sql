-- Deploy 0814-cms:message-revisions/policies/delete-mine to pg
-- requires: message-revisions

BEGIN;

create policy delete_mine
  on app_public.message_revisions
  for delete
  to "$DATABASE_VISITOR"
  using (editor_id = app_public.current_user_id());

COMMIT;
