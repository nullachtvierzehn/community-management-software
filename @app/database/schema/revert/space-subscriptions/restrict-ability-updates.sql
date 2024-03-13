-- Revert 0814-cms:space-subscriptions/restrict-ability-updates from pg

BEGIN;

drop trigger _900_restrict_ability_updates on app_public.space_subscriptions;

drop function app_hidden.restrict_ability_updates_on_space_subscriptions();

COMMIT;
