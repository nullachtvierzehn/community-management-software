-- Deploy 0814-cms:space-submissions/policies/select-submissions-that-I-can-review to pg
-- requires: space-submissions

BEGIN;

create policy select_submissions_that_I_can_review
on app_public.space_submissions
for select
to "$DATABASE_VISITOR"
using (exists(
  select from app_public.space_items as i
  join app_public.spaces as s on (i.space_id = s.id)
  where
    i.space_id in (select app_public.my_space_ids(with_any_abilities := '{accept,manage}'))
   or s.organization_id in (select app_public.my_organization_ids(with_any_abilities := '{accept,manage}'))
));

COMMIT;
