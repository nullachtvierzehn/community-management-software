-- Revert 0814-cms:organizations/my-organization-ids from pg

BEGIN;

drop function app_public.my_organization_ids(app_public.ability[], app_public.ability[]);

COMMIT;
