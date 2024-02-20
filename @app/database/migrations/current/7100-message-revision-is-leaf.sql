create or replace function app_public.message_revisions_is_leaf(revision app_public.message_revisions)
  returns boolean
  language sql
  stable
  parallel safe
  security definer
  set search_path = pg_catalog, public, pg_temp
as $$
  select not exists (
    select from app_public.message_revisions
    where (id, parent_revision_id) = (revision.id, revision.revision_id)
  )
$$;

comment on function app_public.message_revisions_is_leaf(revision app_public.message_revisions) is $$
  @behavior +typeField +filterBy
  $$;


