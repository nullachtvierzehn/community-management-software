-- Deploy 0814-cms:spaces/policies/can-manage-depending-on-abilities to pg
-- requires: spaces/my-space-ids

BEGIN;

create policy can_manage_with_matching_abilities
on app_public.spaces
for all
to "$DATABASE_VISITOR"
using (id in (select app_public.my_space_ids(with_any_abilities => '{manage}')));


COMMIT;
