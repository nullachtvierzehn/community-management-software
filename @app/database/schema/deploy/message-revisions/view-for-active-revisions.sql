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
  where leafs.id = children.parent_revision_id
);

COMMIT;
