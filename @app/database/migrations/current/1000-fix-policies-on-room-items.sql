-- Enter migration here
alter policy manage_by_admins
on app_public.room_items
using (
  room_id IN ( SELECT app_public.my_subscribed_room_ids('admin'))
  and contributed_at is not null
);