-- Deploy 0814-cms:spaces/policies/can-select-if-newly-created to pg
-- requires: spaces

BEGIN;

create policy can_select_if_newly_created
  on app_public.spaces
  for select
  to "$DATABASE_VISITOR"
  using (created_at = current_timestamp);

COMMIT;
