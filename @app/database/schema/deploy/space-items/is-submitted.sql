-- Deploy 0814-cms:space-items/is-submitted to pg
-- requires: space-items/view-for-submissions-and-reviews

BEGIN;

create or replace function app_public.space_items_is_submitted(i app_public.space_items)
returns boolean
language sql
stable
parallel safe
as $$
  select exists (
    select from app_hidden.space_item_submissions_and_reviews
    where
      item_id = i.id
      and item_is_submitted
      and submission_is_active
  )
$$;

comment on function app_public.space_items_is_submitted(i app_public.space_items) is E'@behavior +filterBy +orderBy +typeField';


COMMIT;
