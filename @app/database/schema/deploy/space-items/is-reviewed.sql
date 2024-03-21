-- Deploy 0814-cms:space-items/is-reviewed to pg
-- requires: space-items/view-for-submissions-and-reviews

BEGIN;

create or replace function app_public.space_items_is_reviewed(i app_public.space_items)
returns boolean
language sql
stable
parallel safe
as $$
  select exists (
    select from app_hidden.space_item_submissions_and_reviews
    where
      item_id = i.id
      and submission_is_reviewed
      and submission_is_latest_active
  )
$$;

comment on function app_public.space_items_is_reviewed(i app_public.space_items) is E'@behavior +filterBy +orderBy +typeField';

COMMIT;
