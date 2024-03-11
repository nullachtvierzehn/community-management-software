-- Deploy 0814-cms:space-subscriptions/policies/can-insert-own-subscriptions-if-space-is-open to pg
-- requires: space-subscriptions/my-space-subscription-ids

BEGIN;

create policy can_insert_own_subscriptions_if_space_is_open
  on app_public.space_subscriptions
  for insert
  to "$DATABASE_VISITOR"
  with check (
    subscriber_id = app_public.current_user_id()
    and (abilities is null or abilities <@ '{view}')
    and space_id in (select id from app_public.spaces where is_open)
  );

COMMIT;
