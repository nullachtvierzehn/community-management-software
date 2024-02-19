create policy can_update
on app_public.message_revisions
for update
using (
  --editor_id = app_public.current_user_id() and 
  app_public.message_revisions_is_leaf(message_revisions)
  and not app_public.message_revisions_is_posted(message_revisions)
);