-- Deploy 0814-cms:spaces/policies/select-public-spaces to pg
-- requires: spaces/my-space-ids

BEGIN;

create policy can_select_if_public
on app_public.spaces 
for select
using (is_public);


COMMIT;
