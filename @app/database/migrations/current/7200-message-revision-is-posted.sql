create or replace function app_public.message_revisions_is_posted(revision app_public.message_revisions)
  returns boolean
  language sql
  stable
  parallel safe
  security definer
  set search_path = pg_catalog, public, pg_temp
as $$
  select exists (
    select from app_public.space_postings
    where (message_id, revision_id) = (revision.id, revision.revision_id)
  )
$$;

comment on function app_public.message_revisions_is_posted(revision app_public.message_revisions) is $$
  @behavior +typeField +filterBy
  $$;