-- Deploy 0814-cms:spaces/policies/can-select-if-subscribed to pg
-- requires: spaces/my-space-ids
-- requires: organizations/my-organization-ids

BEGIN;

create policy can_select_if_subscribed
  on app_public.spaces
  for select
  to "$DATABASE_VISITOR"
  using (
    id in (select app_public.my_space_ids(with_any_abilities => '{view,manage}'))
    or organization_id in (select app_public.my_organization_ids(with_any_abilities => '{view,manage}'))
  );

COMMIT;
