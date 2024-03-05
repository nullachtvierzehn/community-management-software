-- Revert 0814-cms:organizations/add-column-default-abilities from pg

BEGIN;

alter table app_public.organizations
  drop column member_abilities,
  drop column owner_abilities;

COMMIT;
