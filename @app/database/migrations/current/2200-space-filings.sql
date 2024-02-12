create table app_public.space_filings (
  id uuid primary key default uuid_generate_v1mc(),
  space_id uuid 
    constraint "space"
      references app_public.spaces (id)
      on update cascade on delete restrict,
  submitter_id uuid
    constraint submitter
      references app_public.users (id)
      on update cascade on delete restrict,
  linked_space_id uuid
    constraint linked_space
      references app_public.spaces (id)
      on update cascade on delete restrict,
  topic_id uuid
    constraint topic
      references app_public.topics (id)
      on update cascade on delete restrict,
  "file_id" uuid
    constraint "file"
      references app_public.files (id)
      on update cascade on delete restrict,
  sort_order float8, 
  slug text 
    constraint valid_slug
      check (slug ~ '^[a-zA-Z0-9.-_~]+$'),
  created_at timestamptz not null default current_timestamp,
  updated_at timestamptz not null default current_timestamp,
  constraint unique_slug_per_space
    unique (space_id, slug),
  constraint links_exactly_one_entity
    check (1 = num_nonnulls(linked_space_id, topic_id, "file_id"))
);


create or replace function app_public.space_filings_item_created_at(filing app_public.space_filings)
  returns timestamptz
  language sql
  stable
  parallel safe
as $$
  select created_at from app_public.spaces where id = filing.linked_space_id
  union all
  select created_at from app_public.topics where id = filing.topic_id
  union all
  select created_at from app_public.files where id = filing.file_id
  limit 1
$$;

comment on function app_public.space_filings_item_created_at(filing app_public.space_filings) is $$
  @behavior -typeField +orderBy
  $$;


create or replace function app_public.space_filings_item_updated_at(filing app_public.space_filings)
  returns timestamptz
  language sql
  stable
  parallel safe
as $$
  select updated_at from app_public.spaces where id = filing.linked_space_id
  union all
  select updated_at from app_public.topics where id = filing.topic_id
  union all
  select updated_at from app_public.files where id = filing.file_id
  limit 1
$$;

comment on function app_public.space_filings_item_updated_at(filing app_public.space_filings) is $$
  @behavior -typeField +orderBy
  $$;


create or replace function app_public.space_filings_item_name(filing app_public.space_filings)
  returns text
  language sql
  stable
  parallel safe
as $$
  select "name" from app_public.spaces where id = filing.linked_space_id
  union all
  select "name" from app_public.topics where id = filing.topic_id
  union all
  select "name" from app_public.files where id = filing.file_id
  limit 1
$$;

comment on function app_public.space_filings_item_name(filing app_public.space_filings) is $$
  @behavior -typeField +orderBy
  $$;



comment on column app_public.space_filings.slug is $$
  A URL path segment. We allow unreserved URI characters according to RFC 3986 (ALPHA / DIGIT / "-" / "." / "_" / "~")
  $$;


comment on constraint "space" on app_public.space_filings 
  is E'@foreignFieldName filings';

grant select on app_public.space_filings to :DATABASE_VISITOR;


comment on table app_public.space_filings is $$
  @ref item to:SpaceItemEntity singular
  @refVia item via:topics
  @refVia item via:files
  $$;