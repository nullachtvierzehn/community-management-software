-- Deploy 0814-cms:message-revisions/view-for-current-revisions to pg
-- requires: message-revisions/view-for-active-revisions

BEGIN;

create or replace view app_public.current_message_revisions
with (check_option = 'cascaded', security_barrier = true, security_invoker = true)
as select
  * 
from app_public.message_revisions as latest
-- We could fetch the latest revisions using `DISTINCT ON`.
-- However, the resulting view would not be automatically updatable.
-- Although possible, we would have to add `INSTEAD OF` triggers for `INSERT`, `UPDATE` and `DELETE`.
-- (If performance problems arise, this might be a feasible resolution.)
where not exists (
  select from app_public.message_revisions as even_later
  where 
    even_later.id = latest.id
    and even_later.updated_at > latest.updated_at
);

alter view app_public.current_message_revisions alter column id set default uuid_generate_v1mc();
alter view app_public.current_message_revisions alter column editor_id set default app_public.current_user_id();

comment on view app_public.current_message_revisions is $$
  @primaryKey id
  $$;

grant select on app_public.current_message_revisions to "$DATABASE_VISITOR";
grant update (editor_id, "subject", body, update_comment) on app_public.current_message_revisions to "$DATABASE_VISITOR";
grant insert (id, parent_revision_id, editor_id, "subject", body, update_comment) on app_public.current_message_revisions to "$DATABASE_VISITOR";
grant delete on app_public.current_message_revisions to "$DATABASE_VISITOR";

COMMIT;
