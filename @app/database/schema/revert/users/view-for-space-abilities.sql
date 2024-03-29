-- Revert 0814-cms:users/view-for-space-abilities from pg

BEGIN;

drop trigger _800_refresh_user_abilities_per_space_after_delete on app_hidden.user_abilities_per_organization;

drop trigger _800_refresh_user_abilities_per_space_after_update on app_hidden.user_abilities_per_organization;

drop trigger _800_refresh_user_abilities_per_space_after_insert on app_hidden.user_abilities_per_organization;

drop function app_hidden.refresh_user_abilities_per_space_when_memberships_change();

drop trigger _800_refresh_user_abilities_per_space_after_update on app_public.space_subscriptions;

drop trigger _800_refresh_user_abilities_per_space_after_insert on app_public.space_subscriptions;

drop function app_hidden.refresh_user_abilities_per_space_when_subscriptions_change();

drop table app_hidden.user_abilities_per_space;

COMMIT;
