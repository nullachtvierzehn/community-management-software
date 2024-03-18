-- Deploy 0814-cms:space-submission-reviews/policies/can-insert to pg
-- requires: spaces/my-space-ids
-- requires: organizations/my-organization-ids

BEGIN;

create policy can_insert
on app_public.space_submission_reviews
for all
to "$DATABASE_VISITOR"
with check (exists(
  select from app_public.space_submissions as sub
  join app_public.space_items as i on (sub.space_item_id = i.id)
  join app_public.spaces as s on (i.space_id = s.id)
  where space_submission_reviews.space_submission_id = sub.id
  -- Revisions must be allowed to the current user.
  and (
    i.space_id in (select app_public.my_space_ids(with_any_abilities => '{manage,accept}'))
    or s.organization_id in (select app_public.my_organization_ids(with_any_abilities => '{manage,accept}'))
  )
));

COMMIT;
