-- Revert 0814-cms:current-user/first-member-organization-id from pg

BEGIN;

drop function app_public.current_user_first_member_organization_id();

COMMIT;
