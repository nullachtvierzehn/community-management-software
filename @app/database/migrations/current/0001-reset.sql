drop table if exists app_public.pdf_files;
drop table if exists app_public.files;

drop function if exists app_public.latest_item(app_public.rooms);
drop function if exists app_public.nth_item_since_last_visit(item app_public.room_items);
drop table if exists app_public.room_items;
drop type if exists app_public.room_item_type;

drop table if exists app_public.room_message_attachments;

drop policy if exists select_if_public_or_subscribed on app_public.room_messages;
drop policy if exists send_messages_to_public_rooms on app_public.room_messages;
drop function if exists app_public.latest_message(room app_public.rooms);
drop function if exists app_public.fetch_draft_in_room(room_id uuid);
drop function if exists app_public.send_room_message(draft_id uuid);
drop function if exists app_public.my_first_interaction(room app_public.rooms);
drop index if exists app_public.room_messages_on_german_fulltext;
drop function if exists app_public.fulltext("message" app_public.room_messages);
drop table if exists app_public.room_messages;

alter table users 
  drop column if exists default_handling_of_notifications,
  drop column if exists sending_time_for_deferred_notifications;

drop policy if exists subscribe_rooms on app_public.room_subscriptions;
drop policy if exists show_subscribed on app_public.rooms;
drop policy if exists manage_as_admin on app_public.rooms;
drop policy if exists select_peers on app_public.room_subscriptions;
drop policy if exists manage_as_moderator on app_public.room_subscriptions;
drop function if exists app_public.my_subscribed_room_ids(app_public.room_role);
drop function if exists app_public.my_room_subscriptions(app_public.room_role);
drop function if exists app_public.my_room_subscription(app_public.rooms);
drop function if exists app_public.my_room_subscription_id(app_public.rooms);
drop function if exists app_public.n_room_subscriptions(room app_public.rooms);
drop function if exists app_public.n_room_subscriptions(room app_public.rooms, min_role app_public.room_role);
drop table if exists app_public.room_subscriptions;
drop type if exists app_public.notification_setting;

drop function if exists app_public.n_items(room app_public.rooms);
drop function if exists app_public.n_items_since(room app_public.rooms, interval);
drop function if exists app_public.n_items_since_date(room app_public.rooms, timestamptz);
drop function if exists app_public.n_items_since_last_visit(room app_public.rooms);
drop table if exists app_public.rooms;
drop type if exists app_public.room_visibility;
drop type if exists app_public.room_history_visibility;
drop type if exists app_public.room_role;

drop function if exists app_public.topics_content_as_plain_text(topic app_public.topics);
drop function if exists app_public.topics_content_teaser(topic app_public.topics);
drop function if exists app_public.topics_content_preview(topic app_public.topics);
drop function if exists app_public.topics_content_preview(topic app_public.topics, integer);

drop table if exists app_public.topics;
drop type if exists app_public.topic_visibility;

drop function if exists app_public.current_user_first_organization_id();
create or replace function app_public.current_user_first_owned_organization_id() returns uuid as $$
  select organization_id 
  from app_public.organization_memberships
  where 
    user_id = app_public.current_user_id() 
    and is_owner = true
  order by created_at asc
  limit 1;
$$ language sql stable security definer set search_path = pg_catalog, public, pg_temp;