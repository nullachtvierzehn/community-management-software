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

comment on table app_public.space_postings is $$
  @ref item to:SubmittableEntity singular
  @refVia item via:topic_revisions
  @refVia item via:message_revisions
  $$;

comment on column app_public.space_postings.slug is $$
  A URL path segment. We allow unreserved URI characters according to RFC 3986 (ALPHA / DIGIT / "-" / "." / "_" / "~")
  $$;

comment on constraint "space" on app_public.space_postings 
  is E'@foreignFieldName posts';
comment on constraint message_revision on app_public.space_postings 
  is E'@foreignFieldName usingPosts';
comment on constraint topic_revision on app_public.space_postings 
  is E'@foreignFieldName usingPosts';
comment on constraint linked_space on app_public.space_postings 
  is E'@foreignFieldName usingPosts';


grant select on app_public.space_postings to :DATABASE_VISITOR;


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

grant execute on function app_public.space_postings_item_created_at(app_public.space_postings) to :DATABASE_VISITOR;
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


create or replace function app_public.spaces_latest_post(s app_public.spaces)
  returns app_public.space_postings
  language sql
  stable
  parallel safe
as $$
  select *
  from app_public.space_postings
  where space_id = s.id
  order by created_at desc
  limit 1
$$;

grant execute on function app_public.spaces_latest_post(app_public.spaces) to :DATABASE_VISITOR;
comment on function app_public.spaces_latest_post(app_public.spaces) is E'@behavior typeField';


create function app_public.space_postings_nth_post_since_last_visit(posting app_public.space_postings)
  returns bigint
  language sql
  stable
  parallel safe
as $$
  with postings_in_same_space as (
    select 
      p.id as id,
      p.space_id,
      case 
        when p.created_at > sub.last_visit_at
        then row_number() over (
          partition by p.space_id, p.created_at > sub.last_visit_at
          order by p.created_at asc
        )
        when p.created_at <= sub.last_visit_at
        then -1 * row_number() over (
          partition by p.space_id, p.created_at > sub.last_visit_at
          order by p.created_at desc
        )
      end as n
    from app_public.space_postings as p
    join app_public.spaces as s on (p.space_id = s.id)
    join lateral app_public.spaces_my_subscription(s) as sub on (true)
  )
  select n 
  from postings_in_same_space 
  where 
    postings_in_same_space.id = posting.id
    and postings_in_same_space.space_id = posting.space_id
$$;

grant execute on function app_public.space_postings_nth_post_since_last_visit(app_public.space_postings) to :DATABASE_VISITOR;
comment on function app_public.space_postings_nth_post_since_last_visit(app_public.space_postings) is E'@behavior typeField +orderBy +filterBy';


create or replace function app_public.spaces_n_posts(s app_public.spaces)
  returns bigint
  language sql
  stable
  parallel safe
as $$
  select count(*) 
  from app_public.space_postings 
  where space_id = s.id 
$$;

grant execute on function app_public.spaces_n_posts(s app_public.spaces) to :DATABASE_VISITOR; 
comment on function app_public.spaces_n_posts(s app_public.spaces)
  is E'@behavior +typeField +orderBy +filterBy';


create or replace function app_public.spaces_n_posts_since(s app_public.spaces, "interval" interval)
  returns bigint
  language sql
  stable
  parallel safe
as $$
  select count(*) 
  from app_public.space_postings 
  where 
    space_id = s.id 
    and created_at > (now() - "interval")
$$;

grant execute on function app_public.spaces_n_posts_since(s app_public.spaces, "interval" interval) to :DATABASE_VISITOR; 
comment on function app_public.spaces_n_posts_since(s app_public.spaces, "interval" interval)
  is E'@behavior +typeField +orderBy +filterBy';


create or replace function app_public.spaces_n_posts_since_date(s app_public.spaces, "date" timestamptz)
  returns bigint
  language sql
  stable
  parallel safe
as $$
  select count(*) 
  from app_public.space_postings 
  where 
    space_id = s.id 
    and created_at > "date"
$$;

grant execute on function app_public.spaces_n_posts_since_date(s app_public.spaces, "date" timestamptz) to :DATABASE_VISITOR; 
comment on function app_public.spaces_n_posts_since_date(s app_public.spaces, "date" timestamptz)
  is E'@behavior +typeField +orderBy +filterBy';


create or replace function app_public.spaces_n_posts_since_last_visit(s app_public.spaces)
  returns bigint
  language sql
  stable
  parallel safe
as $$
  select count(p.*) 
  from app_public.spaces_my_subscription(s) as sub
  join app_public.space_postings as p on (sub.space_id = p.space_id and p.created_at > sub.last_visit_at)
$$;

grant execute on function app_public.spaces_n_posts_since_last_visit(s app_public.spaces) to :DATABASE_VISITOR;
comment on function app_public.spaces_n_posts_since_last_visit(s app_public.spaces)
  is E'@behavior +typeField +orderBy +filterBy';
