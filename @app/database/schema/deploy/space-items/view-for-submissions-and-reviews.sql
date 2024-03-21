-- Deploy 0814-cms:space-items/view-for-submissions-and-reviews to pg
-- requires: space-submission-reviews

BEGIN;

create or replace view app_hidden.space_item_submissions_and_reviews as
select
  s.organization_id,
  i.space_id,
  i.id as item_id,
  i.created_at,
  i.updated_at,
  sub.id as submission_id,
  sub.submitter_id,
  sub.submitted_at,
  r.reviewer_id,
  r.created_at as reviewed_at,
  r.result as review_result,
  (i.editor_id = sub.submitter_id) as is_submitted_by_editor,
  (i.editor_id = r.reviewer_id) as is_reviewed_by_editor,
  (sub.revision_id = i.revision_id) as submission_is_active,
  (
    sub.submitted_at
    < min (sub.submitted_at)
      filter (where sub.revision_id = i.revision_id) -- is active
      over (partition by sub.space_item_id) -- latest submission per space item
  ) as submission_is_old,
  (
    sub.revision_id = i.revision_id
    and sub.submitted_at
    = min (sub.submitted_at)
      filter (where sub.revision_id = i.revision_id)
      over (partition by sub.space_item_id)
  ) as submission_is_first_active,
  (
    sub.revision_id = i.revision_id
    and sub.submitted_at
    = max (sub.submitted_at)
      filter (where sub.revision_id = i.revision_id)
      over (partition by sub.space_item_id)
  ) as submission_is_latest_active,
  (
    sub.submitted_at
    > max (sub.submitted_at)
      filter (where sub.revision_id = i.revision_id) -- is active
      over (partition by sub.space_item_id) -- latest submission per space item
  ) as submission_is_update,
  (sub.id is not null) as item_is_submitted,
  (r.space_submission_id is not null) as submission_is_reviewed
from app_public.space_items as i
join app_public.spaces as s on (i.space_id = s.id)
left join app_public.space_submissions as sub on (i.id = sub.space_item_id)
left join app_public.space_submission_reviews as r on (sub.id = r.space_submission_id);

grant select on app_hidden.space_item_submissions_and_reviews to "$DATABASE_VISITOR";

COMMIT;
