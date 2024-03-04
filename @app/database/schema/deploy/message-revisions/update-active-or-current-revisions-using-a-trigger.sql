-- Deploy 0814-cms:message-revisions/update-active-or-current-revisions-using-a-trigger to pg
-- requires: message-revisions/view-for-active-revisions
-- requires: message-revisions/view-for-current-revisions

BEGIN;

create or replace function app_hidden.update_active_or_current_message_revision()
  returns trigger
  language plpgsql
  volatile
as $$
declare
  old_revision app_public.message_revisions;
  can_still_be_updated boolean;
begin
  if not (old.subject, old.body) is distinct from (new.subject, new.body) then
    return old;
  end if;

  -- Fetch old revision.
  select * into strict old_revision 
    from app_public.message_revisions 
    where id = old.id and revision_id = old.revision_id
    for update;

  -- An existing revision can still be updated, …
  can_still_be_updated := (
    -- … by the same author,
    old_revision.editor_id = app_public.current_user_id()
    -- … if the revision still is active.
    and (old_revision.id, old_revision.revision_id) in (
      select id, revision_id
      from app_public.active_message_revisions
    )
  );

  -- Perform an update, if still possible.
  if can_still_be_updated 
  then
    update app_public.message_revisions as r
    set 
      "subject" = new."subject",
      body = new.body
    where 
      r.id = old_revision.id
      and r.revision_id = old_revision.revision_id
    returning * into strict new;
  
  -- If no longer possible, add another revision istead.
  else
    insert into app_public.message_revisions 
      (id, parent_revision_id, "subject", body)
      values (old.id, old.revision_id, new.subject, new.body)
      returning * into strict new;
  end if;
  
  -- Return 
  return new;
end
$$;

create trigger _500_update_active_message_revision
  instead of update 
  on app_public.active_message_revisions
  for each row
  execute procedure app_hidden.update_active_or_current_message_revision();

create trigger _500_update_current_message_revision
  instead of update 
  on app_public.current_message_revisions
  for each row
  execute procedure app_hidden.update_active_or_current_message_revision();

COMMIT;
