create table app_public.space_postings (
  id uuid primary key default uuid_generate_v1mc(),
  space_id uuid 
    constraint "space"
      references app_public.spaces (id)
      on update cascade on delete restrict,
  poster_id uuid
    constraint poster
      references app_public.users (id)
      on update cascade on delete restrict,
  
  -- linked entities
  linked_space_id uuid,
  topic_id uuid,
  message_id uuid,
  constraint links_exactly_one_entity
    check (1 = num_nonnulls(linked_space_id, topic_id, message_id)),
  constraint linked_space
    foreign key (linked_space_id)
    references app_public.spaces (id)
    on update cascade on delete restrict,
  
  -- linked revisions
  revision_id uuid,
  constraint message_revision
    foreign key (message_id, revision_id)
      references app_public.message_revisions (id, revision_id)
      on update cascade on delete restrict,
  constraint topic_revision
    foreign key (topic_id, revision_id)
      references app_public.topic_revisions (id, revision_id)
      on update cascade on delete restrict,

  sort_order float8,
  slug text 
    constraint valid_slug
      check (slug ~ '^[a-zA-Z0-9.-_~]+$'),
  created_at timestamptz not null default current_timestamp,
  updated_at timestamptz not null default current_timestamp,
  constraint unique_slug_per_space
    unique (space_id, slug)
);


create or replace function app_public.space_postings_item_created_at(p app_public.space_postings)
  returns timestamptz
  language sql
  stable
  parallel safe
as $$
  select created_at from app_public.spaces where id = p.linked_space_id
  union all
  select created_at from app_public.topic_revisions where (id, revision_id) = (p.topic_id, p.revision_id)
  union all
  select created_at from app_public.message_revisions where (id, revision_id) = (p.message_id, p.revision_id)
  limit 1
$$;

comment on function app_public.space_postings_item_created_at(filing app_public.space_postings) is $$
  @behavior -typeField +orderBy
  $$;


create or replace function app_public.space_postings_item_updated_at(p app_public.space_postings)
  returns timestamptz
  language sql
  stable
  parallel safe
as $$
  select updated_at from app_public.spaces where id = p.linked_space_id
  union all
  select updated_at from app_public.topic_revisions where (id, revision_id) = (p.topic_id, p.revision_id)
  union all
  select updated_at from app_public.message_revisions where (id, revision_id) = (p.message_id, p.revision_id)
  limit 1
$$;

comment on function app_public.space_postings_item_updated_at(filing app_public.space_postings) is $$
  @behavior -typeField +orderBy
  $$;


create or replace function app_public.space_postings_item_name(p app_public.space_postings)
  returns text
  language sql
  stable
  parallel safe
as $$
  select "name" from app_public.spaces where id = p.linked_space_id
  union all
  select title from app_public.topic_revisions where (id, revision_id) = (p.topic_id, p.revision_id)
  union all
  select "subject" from app_public.message_revisions where (id, revision_id) = (p.message_id, p.revision_id)
  limit 1
$$;

comment on function app_public.space_postings_item_name(filing app_public.space_postings) is $$
  @behavior -typeField +orderBy
  $$;



comment on column app_public.space_postings.slug is $$
  A URL path segment. We allow unreserved URI characters according to RFC 3986 (ALPHA / DIGIT / "-" / "." / "_" / "~")
  $$;


comment on constraint "space" on app_public.space_postings 
  is E'@foreignFieldName postings';

grant select on app_public.space_postings to :DATABASE_VISITOR;


comment on table app_public.space_postings is $$
  @ref item to:SpaceItemEntity singular
  @refVia item via:topics
  @refVia item via:files
  $$;