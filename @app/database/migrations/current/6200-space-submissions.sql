create table app_public.space_submissions (
  id uuid primary key default uuid_generate_v1mc(),
  space_id uuid 
    constraint "space"
      references app_public.spaces (id)
      on update cascade on delete restrict,
  submitter_id uuid
    constraint submitter
      references app_public.users (id)
      on update cascade on delete restrict,
  
  -- update or insert?
  post_to_be_updated_id uuid
    constraint post_to_be_updated
      references app_public.space_postings (id)
      on update cascade on delete cascade,

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
  updated_at timestamptz not null default current_timestamp
);

grant select on app_public.space_submissions to :DATABASE_VISITOR;

comment on constraint "space" on app_public.space_submissions 
  is E'@foreignFieldName submissions';
comment on constraint message_revision on app_public.space_submissions 
  is E'@foreignFieldName usingSubmissions';
comment on constraint topic_revision on app_public.space_submissions 
  is E'@foreignFieldName usingSubmissions';
comment on constraint linked_space on app_public.space_submissions 
  is E'@foreignFieldName usingSubmissions';