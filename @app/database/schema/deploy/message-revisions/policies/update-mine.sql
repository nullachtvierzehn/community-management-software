-- Deploy 0814-cms:message-revisions/policies/update-mine to pg
-- requires: message-revisions

BEGIN;

create policy update_mine
  on app_public.message_revisions
  for update
  to "$DATABASE_VISITOR"
  using (
    editor_id = app_public.current_user_id()
  )
  with check (
    editor_id = app_public.current_user_id()
    -- Do not update revisions that already have successors.
    and not exists (
      select from app_public.message_revisions as children
      where children.parent_revision_id = message_revisions.revision_id
    )
  );

COMMIT;
