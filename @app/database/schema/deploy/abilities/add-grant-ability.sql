-- Deploy 0814-cms:abilities/add-grant-ability to pg
-- requires: abilities

BEGIN;

alter type app_public.ability add value if not exists 'grant' before 'manage';
alter type app_public.ability add value if not exists 'grant__ability' before 'manage';

COMMIT;
