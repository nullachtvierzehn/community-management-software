create extension if not exists pg_trgm with schema public;

drop type if exists 
  app_public.textsearchable_entity, 
  app_public.textsearch_match cascade;

create type app_public.textsearchable_entity as enum ('user', 'topic', 'room');

create type app_public.textsearch_match as (
  id uuid,
  "type" app_public.textsearchable_entity,
  title text,
  snippet text,
  rank_or_similarity float4,
  "user_id" uuid,
  topic_id uuid,
  room_id uuid
);

grant usage on type app_public.textsearch_match, app_public.textsearchable_entity to :DATABASE_VISITOR;

comment on column app_public.textsearch_match."type" is
  E'@notNull\n@behavior +filterBy';
comment on column app_public.textsearch_match.title is
  E'@notNull\n@behavior +orderBy +filterBy';
comment on column app_public.textsearch_match.rank_or_similarity is
  E'@notNull\n@behavior +orderBy +filterBy';

comment on type app_public.textsearch_match is $$
@primaryKey id
@foreignKey (user_id) references app_public.users (id)|@fieldName user
@foreignKey (topic_id) references app_public.topics (id)|@fieldName topic
@foreignKey (room_id) references app_public.rooms (id)|@fieldName room
$$;

create index if not exists users_on_fuzzy_username on app_public.users using gist (username gist_trgm_ops(siglen=12));

create or replace function app_public.global_search(
  term text, 
  entities app_public.textsearchable_entity[] default '{user,topic}'
)
  returns setof app_public.textsearch_match
  language sql
  stable
  parallel safe
  rows 10
as $$
  -- fetch users
  select
    id,
    'user'::app_public.textsearchable_entity as "type",
    username as title,
    null as snippet,
    word_similarity(term, username) as rank_or_similarity,
    id as "user_id",
    null::uuid as topic_id,
    null::uuid as room_id
  from app_public.users
  where
    'user' = any (entities)
    and term <% username
  -- fetch topics
  union all
  select 
    id,
    'topic'::app_public.textsearchable_entity as "type",
    coalesce(title, slug, 'Thema ' || id) as title,
    ts_headline('german', app_hidden.tiptap_document_as_plain_text(topics.content), query) as snippet,
    ts_rank_cd(array[0.3, 0.5, 0.8, 1.0], fulltext_index_column, query, 32 /* normalization to [0..1) by rank / (rank+1) */) as rank_or_similarity,
    null::uuid as "user_id",
    id as topic_id,
    null::uuid as room_id
  from 
    app_public.topics,
    websearch_to_tsquery('german', term) as query
  where
    'topic' = any (entities)
    and query @@ fulltext_index_column
  -- fetch rooms
  union all
  select
    id,
    'room'::app_public.textsearchable_entity as "type",
    coalesce(title, 'Raum ' || id) as title,
    abstract as snippet,
    greatest (
      word_similarity(term, title),
      ts_rank_cd(array[0.3, 0.5, 0.8, 1.0], fulltext_index_column, query, 32 /* normalization to [0..1) by rank / (rank+1) */)
    ) as rank_or_similarity,
    null::uuid as "user_id",
    null::uuid as topic_id,
    id as room_id
  from 
    app_public.rooms,
    websearch_to_tsquery('german', term) as query
  where 
    'room' = any (entities)
    and (query @@ fulltext_index_column or term <% title)
  -- order the union
  order by rank_or_similarity desc
$$;

grant execute on function app_public.global_search(text,app_public.textsearchable_entity[]) to :DATABASE_VISITOR;

comment on function app_public.global_search(text,app_public.textsearchable_entity[]) is $$
@filterable
@sortable
$$;