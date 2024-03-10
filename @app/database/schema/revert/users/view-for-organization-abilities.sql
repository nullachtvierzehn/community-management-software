-- Revert 0814-cms:users/view-for-organization-abilities from pg

BEGIN;

drop function app_hidden.refresh_user_abilities_per_organization_when_memberships_change() cascade;

drop function app_hidden.refresh_user_abilities_per_organization_on_update() cascade;

drop table app_hidden.user_abilities_per_organization;

COMMIT;
