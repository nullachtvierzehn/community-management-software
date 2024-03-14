-- Deploy 0814-cms:organizations/my-organization-ids to pg
-- requires: users/view-for-organization-abilities

BEGIN;

create or replace function app_public.my_organization_ids(
  with_any_abilities app_public.ability[] default '{view,manage}',
  with_all_abilities app_public.ability[] default '{}'
)
  returns setof uuid
  language sql
  stable
  rows 30
  parallel safe
  security definer
  set search_path = pg_catalog, public, pg_temp
as $$
select organization_id
from app_hidden.user_abilities_per_organization
where
  "user_id" = app_public.current_user_id()
  and with_any_abilities && abilities
  and with_all_abilities <@ abilities
$$;

grant execute on function app_public.my_organization_ids(app_public.ability[], app_public.ability[]) to "$DATABASE_VISITOR";


COMMIT;
