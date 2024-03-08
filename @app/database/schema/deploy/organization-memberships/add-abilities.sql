-- Deploy 0814-cms:organization-memberships/add-abilities to pg
-- requires: abilities
-- requires: initial

BEGIN;

alter table app_public.organization_memberships
  add column abilities app_public.ability[];

COMMIT;
