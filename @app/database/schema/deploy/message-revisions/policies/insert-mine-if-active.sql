-- Deploy 0814-cms:message-revisions/policies/insert-mine-if-active to pg
-- requires: message-revisions

BEGIN;

create policy insert_mine_if_active
  on app_public.message_revisions
  for insert
  to "$DATABASE_VISITOR"
  with check (editor_id = app_public.current_user_id());

COMMIT;
