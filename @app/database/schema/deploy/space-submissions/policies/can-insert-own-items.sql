-- Deploy 0814-cms:space-submissions/policies/can-insert-own-items to pg
-- requires: space-submissions
-- requires: users/view-for-space-abilities

BEGIN;

create policy can_insert_own_items
on app_public.space_submissions
for insert
to "$DATABASE_VISITOR"
with check (exists(
  select from app_public.space_items as i
  join app_public.spaces as s on (i.space_id = s.id)
  where space_submissions.space_item_id = i.id
    -- You may only submit your own space items.
    and space_submissions.submitter_id = i.editor_id
    -- Submissions must match the entity of the space item, but may differ in versions, e.g. to submit updates.
    and (space_submissions.message_id) is not distinct from (i.message_id)
    -- Submissions must be allowed to the current user.
    and (
      i.space_id in (select app_public.my_space_ids(with_any_abilities => '{manage,submit}'))
      or s.organization_id in (select app_public.my_space_ids(with_any_abilities => '{manage,submit}'))
    )
));

COMMIT;
