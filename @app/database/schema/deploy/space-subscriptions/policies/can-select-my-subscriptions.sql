-- Deploy 0814-cms:space-subscriptions/policies/can-select-my-subscriptions to pg
-- requires: space-subscriptions/my-space-subscription-ids

BEGIN;

create policy can_select_my_subscriptions
  on app_public.space_subscriptions
  for select
  to "$DATABASE_VISITOR"
  using (id in (select app_public.my_space_subscription_ids()));

COMMIT;
