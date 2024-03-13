-- Deploy 0814-cms:users/view-for-space-abilities to pg
-- requires: abilities/add-grant-ability
-- requires: space-subscriptions

BEGIN;

create table app_hidden.user_abilities_per_space as
select
  sub.subscriber_id as "user_id",
  sub.space_id,
  array(
    select unnest(sub.abilities)
    union 
    select unnest(oa.abilities)
  ) as abilities,
  array(
    select unnest(sub.abilities) where '{manage,grant,grant__ability}' && sub.abilities
    union 
    select unnest(oa.abilities) where '{manage,grant,grant__ability}' && oa.abilities
  ) as abilities_with_grant_option
from app_public.space_subscriptions as sub
join app_public.spaces as s on (sub.space_id = s.id)
-- Organization memberships are optional. For members, abilities propagate to the spaces of an organization.
left join app_hidden.user_abilities_per_organization as oa on (s.organization_id = oa.organization_id and sub.subscriber_id = oa.user_id);


alter table app_hidden.user_abilities_per_space
  add constraint space_subscription
    foreign key (space_id, "user_id")
    references app_public.space_subscriptions (space_id, subscriber_id)
    on update cascade on delete cascade,
  add constraint "user"
    foreign key ("user_id")
    references app_public.users (id)
    on update cascade on delete cascade,
  add constraint "space"
    foreign key (space_id)
    references app_public.spaces (id)
    on update cascade on delete cascade;

-- Create indices.
create unique index if not exists user_abilities_per_space_on_user_id_space_id
  on app_hidden.user_abilities_per_space ("user_id", space_id) include (abilities);
create index if not exists user_abilities_per_space_on_space_id
  on app_hidden.user_abilities_per_space (space_id);


-- Update view from subscriptions.
create or replace function app_hidden.refresh_user_abilities_per_space_when_subscriptions_change()
  returns trigger
  language plpgsql
  volatile
  security definer
  set search_path = pg_catalog, public, pg_temp
as $$
begin
  -- Step 1: Delete old subscriptions, if not updated.
  -- Afterwards, there are no more rows of old_subscriptions, 
  -- that are not also included in new_subscriptions.
  -- That is important for step 2.
  if tg_op = 'UPDATE' then
    delete from app_public.space_subscriptions
    where (space_id, subscriber_id) in (
      select space_id, subscriber_id from old_subscriptions
      except 
      select space_id, subscriber_id from new_subscriptions
    );
  end if;

  -- Step 2: Update or create memberships.
  with new_abilities_per_user_and_space as (
    select
      sub.subscriber_id as "user_id",
      sub.space_id,
      array(
        select unnest(sub.abilities)
        union 
        select unnest(oa.abilities)
      ) as abilities,
      array(
        select unnest(sub.abilities) 
        where 
          '{manage,grant,grant__ability}' && sub.abilities
          or '{manage,grant,grant__ability}' && oa.abilities
        union 
        select unnest(oa.abilities) where '{manage,grant,grant__ability}' && oa.abilities
      ) as abilities_with_grant_option
    from new_subscriptions as sub
    join app_public.spaces as s on (sub.space_id = s.id)
    -- Organization memberships are optional. For members, abilities propagate to the spaces of an organization.
    left join app_hidden.user_abilities_per_organization as oa on (s.organization_id = oa.organization_id and sub.subscriber_id = oa.user_id)
  )
  merge into app_hidden.user_abilities_per_space as t
  using new_abilities_per_user_and_space as s 
    on (t.space_id = s.space_id and t."user_id" = s."user_id")
  when matched and s.abilities is distinct from t.abilities then
    update set abilities = s.abilities, abilities_with_grant_option = s.abilities_with_grant_option
  when not matched then
    insert ("user_id", space_id, abilities, abilities_with_grant_option) values (s."user_id", s.space_id, s.abilities, s.abilities_with_grant_option);
  
  return new;
end
$$;

create trigger _800_refresh_user_abilities_per_space_after_insert
  after insert
  on app_public.space_subscriptions
  referencing new table as new_subscriptions
  for each statement
  execute function app_hidden.refresh_user_abilities_per_space_when_subscriptions_change();

create trigger _800_refresh_user_abilities_per_space_after_update
  after update
  on app_public.space_subscriptions
  referencing new table as new_subscriptions old table as old_subscriptions
  for each statement
  execute function app_hidden.refresh_user_abilities_per_space_when_subscriptions_change();


-- Update view from organization memberships.
create or replace function app_hidden.refresh_user_abilities_per_space_when_memberships_change()
  returns trigger
  language plpgsql
  volatile
  security definer
  set search_path = pg_catalog, public, pg_temp
as $$
declare
  affected_user_ids uuid[] := '{}';
begin
  if tg_op in ('DELETE', 'UPDATE') then
    affected_user_ids := (select array(select "user_id" from old_memberships) || affected_user_ids);
  end if;

  if tg_op in ('INSERT', 'UPDATE') then
    affected_user_ids := (select array(select "user_id" from new_memberships) || affected_user_ids);
  end if;

  with new_abilities_per_user_and_space as (
    select
      sub.subscriber_id as "user_id",
      sub.space_id,
      array(
        select unnest(sub.abilities)
        union 
        select unnest(oa.abilities)
      ) as abilities,
      array(
        select unnest(sub.abilities) where '{manage,grant,grant__ability}' && sub.abilities
        union 
        select unnest(oa.abilities) where '{manage,grant,grant__ability}' && oa.abilities
      ) as abilities_with_grant_option
    from app_public.space_subscriptions as sub
    join app_public.spaces as s on (sub.space_id = s.id)
    -- Organization memberships are optional. For members, abilities propagate to the spaces of an organization.
    left join app_hidden.user_abilities_per_organization as oa on (s.organization_id = oa.organization_id and sub.subscriber_id = oa.user_id)
    where sub.subscriber_id = any (affected_user_ids)
  )
  merge into app_hidden.user_abilities_per_space as t
  using new_abilities_per_user_and_space as s 
    on (t.space_id = s.space_id and t."user_id" = s."user_id")
  when matched and s.abilities is distinct from t.abilities then
    update set abilities = s.abilities, abilities_with_grant_option = s.abilities_with_grant_option
  when not matched then
    insert ("user_id", space_id, abilities, abilities_with_grant_option) values (s."user_id", s.space_id, s.abilities, s.abilities_with_grant_option);

  if tg_op = 'DELETE' then
    return old;
  else
    return new;
  end if;
end
$$;

create trigger _800_refresh_user_abilities_per_space_after_insert
  after insert
  on app_hidden.user_abilities_per_organization
  referencing new table as new_memberships
  for each statement
  execute function app_hidden.refresh_user_abilities_per_space_when_memberships_change();

create trigger _800_refresh_user_abilities_per_space_after_update
  after update
  on app_hidden.user_abilities_per_organization
  referencing new table as new_memberships old table as old_memberships
  for each statement
  execute function app_hidden.refresh_user_abilities_per_space_when_memberships_change();

create trigger _800_refresh_user_abilities_per_space_after_delete
  after delete
  on app_hidden.user_abilities_per_organization
  referencing old table as old_memberships
  for each statement
  execute function app_hidden.refresh_user_abilities_per_space_when_memberships_change();

COMMIT;
