-- Revert 0814-cms:space-subscriptions/auto-subscribe-after-space-creation from pg

BEGIN;

drop trigger _500_auto_subscribe_after_space_creation on app_public.spaces;

drop function app_hidden.auto_subscribe_after_space_creation();

alter table app_public.organizations
  drop column space_creator_abilities;

COMMIT;
