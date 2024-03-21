-- Deploy 0814-cms:space-items/policies/select-approved to pg
-- requires: space-items/view-for-submissions-and-reviews
-- requires: spaces/my-space-ids
-- requires: organizations/my-organization-ids

BEGIN;

create policy select_approved
on app_public.space_items
for select
to "$DATABASE_VISITOR"
using ('approved' = any (
  select review_result
  from app_hidden.space_item_submissions_and_reviews
  where
    submission_is_active
    and item_id = space_items.id
    and (
      space_id in (select app_public.my_space_ids(with_any_abilities => '{view,manage}'))
      or organization_id in (select app_public.my_organization_ids(with_any_abilities => '{view,manage}'))
    )
));

COMMIT;
