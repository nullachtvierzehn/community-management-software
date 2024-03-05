-- Deploy 0814-cms:abilities to pg
-- requires: initial

BEGIN;

create type app_public.ability as enum (
  'view',
  'create',
  'create__space',
  'create__message',
  'create__file',
  'update',
  'update__space',
  'update__message',
  'update__file',
  'delete',
  'delete__space',
  'delete__message',
  'delete__file',
  'submit',
  'submit__message',
  'submit__file',
  'accept',
  'accept__message',
  'accept__file',
  'manage'
);

COMMIT;
