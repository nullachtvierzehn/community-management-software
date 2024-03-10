-- Deploy 0814-cms:spaces/policies/can-create-root-spaces-when-organization-abilities-match to pg
-- requires: spaces
-- requires: users/view-for-organization-abilities

BEGIN;

create policy can_create_root_spaces_when_organization_abilities_match
  on app_public.spaces
  for insert 
  to "$DATABASE_VISITOR"
  with check (exists(
    select from app_hidden.user_abilities_per_organization
    where
      "user_id" = app_public.current_user_id()
      and organization_id in (select app_public.current_user_member_organization_ids())
      and organization_id = spaces.organization_id
      and '{create__space,create,manage}' && abilities
  ));

COMMIT;
