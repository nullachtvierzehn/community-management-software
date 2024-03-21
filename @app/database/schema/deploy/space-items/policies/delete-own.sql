-- Deploy 0814-cms:space-items/policies/delete-own to pg
-- requires: space-items

BEGIN;

create policy delete_own
on app_public.space_items
for delete
to "$DATABASE_VISITOR"
using (editor_id = app_public.current_user_id());

COMMIT;
