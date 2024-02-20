create or replace view app_public.current_message_revisions
  with (security_invoker=true, security_barrier=true, check_option=cascaded) as 
  select tip.*
  from app_public.active_message_revisions as tip
  where (tip.created_at, tip.revision_id) >= all (
    select created_at, revision_id
    from app_public.active_message_revisions as others
    where tip.id = others.id
  );

comment on view app_public.current_message_revisions is $$
  @primaryKey id
  @foreignKey (editor_id) references app_public.users (id)
  $$;

grant select on app_public.current_message_revisions to :DATABASE_VISITOR;
grant insert (id, parent_revision_id, editor_id, "subject", body) on app_public.current_message_revisions to :DATABASE_VISITOR;
grant update (editor_id, "subject", body) on app_public.current_message_revisions to :DATABASE_VISITOR;
grant delete on app_public.current_message_revisions to :DATABASE_VISITOR;


create or replace function app_hidden.update_active_message_revision()
  returns trigger
  language plpgsql
as $$
declare
  new_revision app_public.message_revisions;
  old_revision app_public.message_revisions;
  can_I_update boolean;
begin
  if not (old.subject, old.body) is distinct from (new.subject, new.body) then
    return old;
  end if;

  select * into strict old_revision 
    from app_public.message_revisions 
    where id = old.id and revision_id = old.revision_id
    for update;

  can_I_update := (
    old_revision.editor_id = app_public.current_user_id()
    and app_public.message_revisions_is_leaf(old_revision)
    and not app_public.message_revisions_is_posted(old_revision)
    or true
  );

  if can_I_update then
    update app_public.message_revisions as r
    set 
      "subject" = new."subject",
      body = new.body
    where 
      r.id = old_revision.id
      and r.revision_id = old_revision.revision_id
    returning * into strict new;
  else
    insert into app_public.message_revisions 
      (id, parent_revision_id, "subject", body)
      values (old.id, old.revision_id, new.subject, new.body)
      returning * into strict new_revision;
    new.revision_id := new_revision.revision_id;
    new.created_at := new_revision.created_at;
  end if;
  
  return new;
end
$$;

create trigger _500_update_active_message_revision
  instead of update
  on app_public.active_message_revisions
  for each row
  execute function app_hidden.update_active_message_revision();