-- Deploy 0814-cms:space-submissions/policies/select-own to pg
-- requires: space-submissions

BEGIN;

create policy select_own
on app_public.space_submissions
for select
to "$DATABASE_VISITOR"
using (submitter_id = app_public.current_user_id());

COMMIT;
