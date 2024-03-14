-- Deploy 0814-cms:spaces/policies/can-select-if-subscribed to pg
-- requires: spaces/my-space-ids

BEGIN;

create policy can_select_if_subscribed
  on app_public.spaces
  for select
  to "$DATABASE_VISITOR"
  using (id in (select app_public.my_space_ids(with_any_abilities => '{view,manage}')));

COMMIT;
