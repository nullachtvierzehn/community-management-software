-- Deploy 0814-cms:message-revisions/view-for-active-revisions to pg
-- requires: message-revisions

BEGIN;

create or replace view app_public.active_message_revisions
with (check_option = 'cascaded', security_barrier = true, security_invoker = true)
as select 
  * 
from app_public.message_revisions as leafs
where not exists (
  select from app_public.message_revisions as children
  where leafs.revision_id = children.parent_revision_id
);

alter view app_public.active_message_revisions alter column id set default uuid_generate_v1mc();
alter view app_public.active_message_revisions alter column editor_id set default app_public.current_user_id();

comment on view app_public.active_message_revisions is $$
  @primaryKey id,revision_id
  $$;

grant select on app_public.active_message_revisions to "$DATABASE_VISITOR";
grant update (editor_id, "subject", body, update_comment) on app_public.active_message_revisions to "$DATABASE_VISITOR";
grant insert (id, parent_revision_id, editor_id, "subject", body, update_comment) on app_public.active_message_revisions to "$DATABASE_VISITOR";
grant delete on app_public.active_message_revisions to "$DATABASE_VISITOR";

COMMIT;
