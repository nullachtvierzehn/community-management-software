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
drop table if exists app_public.room_subscriptions;
drop type if exists app_public.room_role;
drop type if exists app_public.notification_setting;

drop table if exists app_public.rooms;
drop type if exists app_public.room_visibility;
drop type if exists app_public.room_history_visibility;

create or replace function app_public.current_user_first_organization_id() returns uuid as $$
  select organization_id 
  from app_public.organization_memberships
  where user_id = app_public.current_user_id()
  order by created_at asc
  limit 1;
$$ language sql stable security definer set search_path = pg_catalog, public, pg_temp;