-- Deploy 0814-cms:message-revisions/policies/insert-mine-if-active to pg
-- requires: message-revisions

BEGIN;

create policy insert_mine_if_active
  on app_public.message_revisions
  for insert
  to "$DATABASE_VISITOR"
  with check (
    editor_id = app_public.current_user_id()
    -- Do not insert revisions that already have successors.
    and not exists (
      select from app_public.message_revisions as children
      where children.parent_revision_id = message_revisions.revision_id
    )
  );

COMMIT;
