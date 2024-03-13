-- Deploy 0814-cms:space-subscriptions/policies/can-update-my-own-policies to pg
-- requires: space-subscriptions/my-space-subscription-ids

BEGIN;

create policy can_update_my_subscriptions
  on app_public.space_subscriptions
  for update
  to "$DATABASE_VISITOR"
  using (id in (select app_public.my_space_subscription_ids()));

COMMIT;
