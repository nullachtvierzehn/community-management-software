-- Revert 0814-cms:organization-memberships/add-abilities from pg

BEGIN;

alter table app_public.organization_memberships
  drop column abilities;

COMMIT;
