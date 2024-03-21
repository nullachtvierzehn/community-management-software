-- Deploy 0814-cms:space-items/policies/select-submitted to pg
-- requires: space-items/view-for-submissions-and-reviews
-- requires: spaces/my-space-ids
-- requires: organizations/my-organization-ids

BEGIN;

create policy select_submitted
on app_public.space_items
for select
to "$DATABASE_VISITOR"
using (id in (
  select item_id
  from app_hidden.space_item_submissions_and_reviews
  where
    item_is_submitted
    and (
      space_id in (select app_public.my_space_ids(with_any_abilities => '{accept,manage}'))
      or organization_id in (select app_public.my_organization_ids(with_any_abilities => '{accept,manage}'))
    )
));

COMMIT;
