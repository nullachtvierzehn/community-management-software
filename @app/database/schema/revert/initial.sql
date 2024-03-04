-- Revert 0814-cms:initial from pg

BEGIN;

drop schema if exists app_public cascade;
drop schema if exists app_hidden cascade;
drop schema if exists app_private cascade;

COMMIT;
