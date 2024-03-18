-- Deploy 0814-cms:space-items/view-for-submission-and-approval-times to pg
-- requires: space-submission-reviews

BEGIN;

create or replace view app_hidden.space_item_submission_and_approval_times as
select
  s.organization_id,
  i.space_id,
  i.id as space_item_id,
  i.created_at,
  i.updated_at,
  i.editor_id,
  stats.*
from app_public.space_items as i
join app_public.spaces as s on (i.space_id = s.id)
left join lateral (
  select
    min(s.submitted_at) as first_submission_at,
    min(r.created_at) as first_approval_at,
    min(s.submitted_at) filter (where (i.message_id, i.revision_id) is not distinct from (s.message_id, s.revision_id)) as current_submission_since,
    min(r.created_at) filter (where (i.message_id, i.revision_id) is not distinct from (s.message_id, s.revision_id)) as current_approval_since,
    max(s.submitted_at) as last_submission_at,
    max(r.created_at) as last_approval_at
  from app_public.space_submissions as s
  left join app_public.space_submission_reviews as r on (s.id = r.space_submission_id and r.result = 'approved')
  where i.id = s.space_item_id
) as stats on (true);

grant select on app_hidden.space_item_submission_and_approval_times to "$DATABASE_VISITOR";


create or replace view app_public.space_item_submission_and_approval_times as
select
  t.*
from app_hidden.space_item_submission_and_approval_times as t
left join app_hidden.user_abilities_per_space as sa on (
  t.space_id = sa.space_id
  and sa.user_id = app_public.current_user_id()
)
left join app_hidden.user_abilities_per_organization as oa on (
  t.organization_id = oa.organization_id
  and oa.user_id = app_public.current_user_id()
)
where
(
  -- Currently approved items can be seen by all space members.
  t.current_approval_since is not null
  and (sa.abilities && '{view,manage}' or oa.abilities && '{view,manage}')
)
or (
  -- Currently submitted items can be seen by reviewers.
  t.current_submission_since is not null
  and (sa.abilities && '{accept,manage}' or oa.abilities && '{accept,manage}')
);

grant select on app_public.space_item_submission_and_approval_times to "$DATABASE_VISITOR";


comment on view app_public.space_item_submission_and_approval_times is $$
  @primaryKey space_item_id
  @foreignKey (space_item_id) references app_public.space_items (id)|@fieldName item|@foreignFieldName times
  @foreignKey (space_id) references app_public.spaces (id)
  @foreignKey (organization_id) references app_public.organizations (id)
  @omit create,update,delete,all
  $$;

COMMIT;
