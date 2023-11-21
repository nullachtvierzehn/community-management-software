create table app_public.room_messages (
  id uuid primary key default uuid_generate_v1mc(),
  room_id uuid not null
    constraint room
      references app_public.rooms (id)
      on update cascade on delete cascade,
  sender_id uuid
    default app_public.current_user_id()
    constraint sender
      references app_public.users (id)
      on update cascade on delete set null,
  answered_message_id uuid
    constraint answered_message
      references app_public.room_messages (id)
      on update cascade on delete restrict,
  body text,
  language text not null default 'german'
    constraint supported_language check (language in ('german', 'english', 'french')),
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  updated_at timestamptz not null default now()
);

comment on constraint answered_message on app_public.room_messages is E'@fieldName answeredMessage\n@foreignFieldName answers';
comment on constraint room on app_public.room_messages is E'@foreignFieldName messages';

create function app_public.fulltext("message" app_public.room_messages)
returns tsvector
language sql
immutable
parallel safe
as $$
  select to_tsvector(cast("message".language as regconfig), "message".body)
$$;

comment on function app_public.fulltext(app_public.room_messages) is E'@behavior typeField';

grant execute on function app_public.fulltext(app_public.room_messages) to :DATABASE_VISITOR;

create index room_messages_on_room_id on app_public.room_messages (room_id);
create index room_messages_on_sender_id on app_public.room_messages (sender_id);
create index room_messages_on_answered_message_id on app_public.room_messages (answered_message_id);
create index room_messages_on_german_fulltext on app_public.room_messages using gin ((app_public.fulltext(row(app_public.room_messages.*))));
create index room_messages_on_created_at on app_public.room_messages using brin (created_at);
create index room_messages_on_sent_at on app_public.room_messages (sent_at);
create index room_messages_on_updated_at on app_public.room_messages (updated_at);

grant select on app_public.room_messages to :DATABASE_VISITOR;
grant insert (room_id, body, sender_id, language, answered_message_id, sent_at) on app_public.room_messages to :DATABASE_VISITOR;
grant update (body, language, answered_message_id, sent_at) on app_public.room_messages to :DATABASE_VISITOR;
grant delete on app_public.room_messages to :DATABASE_VISITOR;

alter table app_public.room_messages enable row level security;

create function app_public.my_first_interaction(room app_public.rooms)
returns timestamptz
  language sql
  stable
  security definer
 set search_path = pg_catalog, public, pg_temp
as $$
  select least (
    -- my earliest sent message
    (select min(sent_at) from app_public.room_messages where room_messages.room_id = room.id),
    -- my subscription date
    (select min(created_at) from app_public.room_subscriptions where room_subscriptions.room_id = room.id and room_subscriptions.subscriber_id = app_public.current_user_id())
  )
$$;

comment on function app_public.my_first_interaction(room app_public.rooms) is $$
@behavior typeField

Date of subscription or first sent message, whatever is earlier.
$$;

grant execute on function app_public.my_first_interaction(room app_public.rooms) to :DATABASE_VISITOR;

create trigger _100_timestamps
  before insert or update on app_public.room_messages
  for each row
  execute procedure app_private.tg__timestamps();

create policy require_messages_from_current_user
on app_public.room_messages
as restrictive
for insert
to :DATABASE_VISITOR
with check (sender_id = app_public.current_user_id());

create policy only_authors_should_access_their_message_drafts
on app_public.room_messages
as restrictive
for all
to :DATABASE_VISITOR
using (sent_at is not null or sender_id = app_public.current_user_id());

create policy send_messages_to_public_rooms
on app_public.room_messages
for insert
with check (room_id in (select id from app_public.rooms where visibility >= 'public'));

create policy update_own_messages
on app_public.room_messages
for update
using (sender_id = app_public.current_user_id());

create policy select_if_public_or_subscribed
on app_public.room_messages
for select
using (
  exists (
    select from app_public.rooms as r
    left join lateral app_public.my_room_subscription(r) as s on (true)
    where 
      room_messages.room_id = r.id
      and (
        -- Show all messages of rooms that I can see, if the history is public.
        r.visibility_of_history >= 'public'
        -- Show all messages of rooms that I can see since a specified date.
        or (
          r.visibility_of_history >= 'since_specified_date'
          and room_messages.created_at >= (r.visibility_of_history_since - r.visibility_of_history_extended_by)
        )
        -- Show all messages of rooms that I subscribe, since I subscribed.
        or (
          r.visibility_of_history >= 'since_subscription'
          and room_messages.created_at >= (s.created_at - r.visibility_of_history_extended_by)
        )
      )
  )
);

create policy select_my_drafts
on app_public.room_messages
for select
using (
  sent_at is null
  and sender_id = app_public.current_user_id()
);

create function app_public.send_room_message(draft_id uuid, out room_message app_public.room_messages)
  language plpgsql
  volatile
  security definer
  set search_path = pg_catalog, public, pg_temp
as $$
declare
  v_message app_public.room_messages;
  v_my_id uuid;
begin
  -- check for login
  v_my_id := app_public.current_user_id();
  if v_my_id is null then
    raise exception 'You must log to submit a draft' using errcode = 'LOGIN';
  end if;

  -- fetch message
  select * into room_message from app_public.room_messages where room_messages.id = send_room_message.draft_id and room_messages.sender_id = v_my_id;
  if not found then
    raise exception 'Could not find draft' using errcode = 'NTFND';
  end if;

  -- deny request if room message has already been sent at an ealier time.
  if room_message.sent_at is not null then
    raise exception 'message has already been sent' using errcode = 'DNIED';
  end if;

  -- mark this room message as sent
  update app_public.room_messages
    set sent_at = current_timestamp
    where room_messages.id = room_message.id
    returning * into room_message;
end
$$;

create function app_public.fetch_draft_in_room(room_id uuid)
returns app_public.room_messages
language sql
stable
parallel safe
as $$
  select * from app_public.room_messages
  where
    room_messages.room_id = fetch_draft_in_room.room_id
    and sent_at is null
    and sender_id = app_public.current_user_id()
$$;

create function app_public.latest_message(room app_public.rooms)
returns app_public.room_messages
language sql
stable
parallel safe
as $$
  select *
  from app_public.room_messages
  where
    room_id = room.id
    and sent_at is not null
  order by sent_at desc
  limit 1
$$;

grant execute on function app_public.latest_message(app_public.rooms) to :DATABASE_VISITOR;
comment on function app_public.latest_message(app_public.rooms) is E'@behavior typeField';


create table if not exists app_public.room_message_attachments (
  id uuid primary key default uuid_generate_v1mc(),
  room_message_id uuid not null
    constraint room_message references app_public.room_messages (id)
    on update cascade on delete cascade,
  topic_id uuid not null
    constraint topic references app_public.topics (id)
    on update cascade on delete cascade,
  created_at timestamptz not null default now(),
  constraint unique_powerup_exercises_per_room_message_id
    unique (topic_id, room_message_id)
);

comment on constraint room_message on app_public.room_message_attachments is
  E'@fieldName message\n@foreignFieldName attachments';

create index room_message_attachments_on_room_message_id on app_public.room_message_attachments (room_message_id);
create index room_message_attachments_on_topic_id on app_public.room_message_attachments (topic_id);
create index room_message_attachments_on_created_at on app_public.room_message_attachments using brin (created_at);

grant select on app_public.room_message_attachments to :DATABASE_VISITOR;
grant insert (id, room_message_id, topic_id) on app_public.room_message_attachments to :DATABASE_VISITOR;
grant delete on app_public.room_message_attachments to :DATABASE_VISITOR;

alter table app_public.room_message_attachments enable row level security;

create policy select_attachments 
on app_public.room_message_attachments
for select
using (
  -- Show attachments for all messages that I can see.
  exists (
    select from app_public.room_messages as m
    where room_message_attachments.room_message_id = m.id
  )
);

create policy add_attachments 
on app_public.room_message_attachments
for insert
with check (
  exists (
    select from app_public.room_messages as m
    where 
      room_message_attachments.room_message_id = m.id
      and m.sender_id = app_public.current_user_id()
  )
);

create policy delete_attachments
on app_public.room_message_attachments
for delete
using (
  exists (
    select from app_public.room_messages as m
    where 
      room_message_attachments.room_message_id = m.id
      and m.sender_id = app_public.current_user_id()
  )
);