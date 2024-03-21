-- Deploy 0814-cms:space-items/latest-active-submission to pg
-- requires: space-items/view-for-submissions-and-reviews

BEGIN;

create or replace function app_public.latest_active_submission(i app_public.space_items)
returns app_public.space_submissions
language sql
stable
parallel safe
as $$
  select s.*
  from app_public.space_submissions as s
  join app_hidden.space_item_submissions_and_reviews as _ on (s.id = _.submission_id)
  where
    submission_is_latest_active
    and s.space_item_id = i.id
  order by s.id limit 1  -- To break ties, if many submissions were inserted during the same database transaction.
$$;

comment on function app_public.latest_active_submission(i app_public.space_items) is E'@behavior +filterBy +orderBy +typeField';

COMMIT;
