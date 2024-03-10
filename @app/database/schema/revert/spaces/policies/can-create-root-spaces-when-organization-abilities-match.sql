-- Revert 0814-cms:spaces/policies/can-create-root-spaces-when-organization-abilities-match from pg

BEGIN;

drop policy can_create_root_spaces_when_organization_abilities_match on app_public.spaces;

COMMIT;
