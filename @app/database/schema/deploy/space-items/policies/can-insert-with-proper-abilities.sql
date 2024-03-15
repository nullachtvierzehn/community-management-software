-- Deploy 0814-cms:space-items/policies/can-insert-with-proper-abilities to pg
-- requires: users/view-for-space-abilities
-- requires: space-items

BEGIN;

create policy can_create_with_proper_abilities
  on app_public.space_items
  for insert
  to "$DATABASE_VISITOR"
  with check (
    space_id in (
      select app_public.my_space_ids(with_any_abilities => '{manage,create}')
      union all
      select id from app_public.spaces
      where organization_id in (
        select app_public.my_organization_ids(with_any_abilities => '{manage,create}')
      )
    )
  );

COMMIT;
