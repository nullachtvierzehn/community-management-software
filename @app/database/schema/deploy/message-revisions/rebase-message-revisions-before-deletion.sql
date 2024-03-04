-- Deploy 0814-cms:message-revisions/rebase-message-revisions-before-deletion to pg
-- requires: message-revisions

BEGIN;

create or replace function app_hidden.rebase_message_revisions_before_deletion()
  returns trigger
  security definer
  language plpgsql
as $$
begin
  update app_public.message_revisions
    set parent_revision_id = old.parent_revision_id
    where 
      id = old.id 
      and parent_revision_id = old.revision_id;
  return old;
end
$$;

create trigger _200_rebase_message_revisions_before_deletion
  before delete
  on app_public.message_revisions
  for each row
  execute function app_hidden.rebase_message_revisions_before_deletion();

COMMIT;
