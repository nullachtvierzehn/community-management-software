-- Deploy 0814-cms:space-submissions/policies/select-own to pg
-- requires: spaces/my-space-ids
-- requires: space-submissions

BEGIN;

create policy select_own
on app_public.space_items
for select
to "$DATABASE_VISITOR"
using (editor_id = app_public.current_user_id());

COMMIT;
