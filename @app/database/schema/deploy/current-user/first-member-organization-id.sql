-- Deploy 0814-cms:current-user/first-member-organization-id to pg
-- requires: initial

BEGIN;

create function app_public.current_user_first_member_organization_id() returns uuid as $$
  select organization_id 
    from app_public.organization_memberships
    where user_id = app_public.current_user_id()
    order by created_at asc
    limit 1;
$$ language sql stable security definer set search_path = pg_catalog, public, pg_temp;

COMMIT;
