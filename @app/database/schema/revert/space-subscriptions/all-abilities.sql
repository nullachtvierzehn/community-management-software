-- Revert 0814-cms:space-subscriptions/all-abilities from pg

BEGIN;

drop function app_public.space_subscriptions_all_abilities(s app_public.space_subscriptions);

drop function app_public.space_subscriptions_all_abilities_with_grant_option(s app_public.space_subscriptions);

COMMIT;
