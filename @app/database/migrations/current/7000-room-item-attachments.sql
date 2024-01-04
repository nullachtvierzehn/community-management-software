create type app_public.room_item_attachment_type as enum ('TOPIC', 'FILE');

grant usage on type app_public.room_item_attachment_type to :DATABASE_VISITOR;

create table app_public.room_item_attachments (
  id uuid primary key default uuid_generate_v1mc(),
  room_item_id uuid not null
    constraint room_item
      references app_public.room_items (id)
      on update cascade on delete cascade,
  topic_id uuid
    constraint topic
      references app_public.topics (id)
      on update cascade on delete restrict,
  file_id uuid
    constraint "file"
      references app_public.files (id)
      on update cascade on delete restrict,
  created_at timestamptz not null default now(),
  constraint either_topic_or_file 
    check (num_nonnulls(topic_id, file_id) = 1)
);

grant select on app_public.room_item_attachments to :DATABASE_VISITOR;
grant insert (id, room_item_id, topic_id, file_id) on app_public.room_item_attachments to :DATABASE_VISITOR;
grant delete on app_public.room_item_attachments to :DATABASE_VISITOR;

create index room_item_attachments_on_room_item_id on app_public.room_item_attachments (room_item_id);
create index room_item_attachments_on_topic_id on app_public.room_item_attachments (topic_id);
create index room_item_attachments_on_file_id on app_public.room_item_attachments (file_id);
create index room_item_attachments_on_created_at on app_public.room_item_attachments using brin (created_at);
