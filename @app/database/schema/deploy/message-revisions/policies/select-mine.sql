-- Deploy 0814-cms:message-revisions/policies/select-mine to pg
-- requires: message-revisions

BEGIN;

create policy select_mine
  on app_public.message_revisions
  for select
  to "$DATABASE_VISITOR"
  using (editor_id = app_public.current_user_id());

COMMIT;
