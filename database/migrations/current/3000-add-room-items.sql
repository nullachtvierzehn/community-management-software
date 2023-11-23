create type app_public.room_item_type as enum (
  'MESSAGE',
  'TOPIC'
);

create table app_public.room_items (
  id uuid primary key default uuid_generate_v1mc(),

  -- rails-style polymorphic column
  type app_public.room_item_type not null default 'MESSAGE',

  -- shared attributes
  room_id uuid not null
    constraint room
      references app_public.rooms (id)
      on update cascade on delete cascade,
  parent_id uuid
    constraint parent
      references app_public.room_items (id)
      on update cascade on delete cascade,
  contributor_id uuid
    default app_public.current_user_id()
    constraint contributor
      references app_public.users (id)
      on update cascade on delete set null,
  position int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  posted_at timestamptz, 

  -- messages
  message_body jsonb,
  constraint valid_message_body check ((
    type = 'MESSAGE'
    and message_body is not null
    and jsonb_typeof(message_body) = 'object'
  ) or (
    type <> 'MESSAGE'
    and message_body is null
  )),

  -- attached topics
  topic_id uuid
    constraint topic
    references app_public.topics (id)
    on update cascade on delete cascade,
  constraint valid_topic_id check (
    (type = 'TOPIC') = (topic_id is not null)
  )
);

grant select on app_public.room_items to :DATABASE_VISITOR;
grant insert (type, room_id, parent_id, contributor_id, position, posted_at, message_body, topic_id) on app_public.room_items to :DATABASE_VISITOR;
grant update (position, posted_at, message_body, topic_id) on app_public.room_items to :DATABASE_VISITOR;
grant delete on app_public.room_items to :DATABASE_VISITOR;