-- Deploy 0814-cms:space-submissions/policies/select-as-reviewer to pg
-- requires: space-items/view-for-submissions-and-reviews
-- requires: spaces/my-space-ids
-- requires: organizations/my-organization-ids

BEGIN;

create policy select_as_reviewer
on app_public.space_submissions
for select
to "$DATABASE_VISITOR"
using (id in (
  select submission_id
  from app_hidden.space_item_submissions_and_reviews
  where
    space_id in (select app_public.my_space_ids(with_any_abilities => '{accept,manage}'))
    or organization_id in (select app_public.my_organization_ids(with_any_abilities => '{accept,manage}'))
));

COMMIT;
