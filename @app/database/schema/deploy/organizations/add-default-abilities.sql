-- Deploy 0814-cms:organizations/add-column-default-abilities to pg
-- requires: abilities
-- requires: initial

BEGIN;

alter table app_public.organizations
  add column member_abilities app_public.ability[] not null default '{create__message,update__message,submit__message}',
  add column owner_abilities app_public.ability[] not null default '{manage}';

COMMIT;
