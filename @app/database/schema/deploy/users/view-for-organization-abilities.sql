-- Deploy 0814-cms:users/view-for-organization-abilities to pg
-- requires: organization-memberships/add-abilities

BEGIN;

create table app_hidden.user_abilities_per_organization as
select
  m.user_id,
  m.organization_id,
  array(
    select distinct e
    from unnest(
      case 
      when m.is_owner then 
        o.owner_abilities || o.member_abilities || m.abilities
      else 
        o.member_abilities || m.abilities
      end
    ) as _(e)
    order by e
  ) as abilities
from app_public.organization_memberships as m
join app_public.organizations as o on (m.organization_id = o.id);

grant select on app_hidden.user_abilities_per_organization to "$DATABASE_VISITOR";


alter table app_hidden.user_abilities_per_organization
  add constraint organization_membership
    foreign key (organization_id, "user_id")
    references app_public.organization_memberships (organization_id, "user_id")
    on update cascade on delete cascade,
  add constraint "user"
    foreign key ("user_id")
    references app_public.users (id)
    on update cascade on delete cascade,
  add constraint organization
    foreign key (organization_id)
    references app_public.organizations (id)
    on update cascade on delete cascade;


-- Create indices.
-- drop index if exists app_hidden.user_abilities_per_organization_on_user_id_organization_id;

create unique index if not exists user_abilities_per_organization_on_organization_id_user_id
  on app_hidden.user_abilities_per_organization ("user_id", organization_id) include (abilities);
create index if not exists user_abilities_per_organization_on_organization_id
  on app_hidden.user_abilities_per_organization (organization_id);

-- Grant privileges.
grant select on app_hidden.user_abilities_per_organization to "$DATABASE_VISITOR";


-- Handle inserts on app_public.organization_memberships
create or replace function app_hidden.refresh_user_abilities_per_organization_when_memberships_change()
  returns trigger
  language plpgsql
  volatile
  security definer
  set search_path = pg_catalog, public, pg_temp
as $$
begin
  -- Step 1: Delete old memberships, if not updated.
  -- Afterwards, there are no more rows of old_memberships, 
  -- that are not also included in new_memberships.
  -- That is important for step 2.
  if tg_op = 'UPDATE' then
    delete from app_public.organization_memberships
    where (organization_id, "user_id") in (
      select organization_id, "user_id" from old_memberships
      except 
      select organization_id, "user_id" from new_memberships
    );
  end if;

  -- Step 2: Update or create memberships.
  with new_abilities_per_user_and_organization as (
    select
      m.user_id,
      m.organization_id,
      array(
        select distinct e
        from unnest(
          case 
          when m.is_owner then 
            o.owner_abilities || o.member_abilities || m.abilities
          else 
            o.member_abilities || m.abilities
          end
        ) as _(e)
        order by e
      ) as abilities
    from new_memberships as m
    join app_public.organizations as o on (m.organization_id = o.id)
  )
  merge into app_hidden.user_abilities_per_organization as t
  using new_abilities_per_user_and_organization as s 
    on (t.organization_id = s.organization_id and t."user_id" = s."user_id")
  when matched and s.abilities is distinct from t.abilities then
    update set abilities = s.abilities
  when not matched then
    insert ("user_id", organization_id, abilities) values (s."user_id", s.organization_id, s.abilities);
  
  return new;
end
$$;

create trigger _800_refresh_user_abilities_per_organization_after_insert
  after insert
  on app_public.organization_memberships
  referencing new table as new_memberships
  for each statement
  execute function app_hidden.refresh_user_abilities_per_organization_when_memberships_change();

create trigger _800_refresh_user_abilities_per_organization_after_update
  after update
  on app_public.organization_memberships
  referencing new table as new_memberships old table as old_memberships
  for each statement
  execute function app_hidden.refresh_user_abilities_per_organization_when_memberships_change();


-- Handle updates of organizations 
-- (We can ignore inserts, because at the time of an insert time, there are no memberships.)
create or replace function app_hidden.refresh_user_abilities_per_organization_on_update()
  returns trigger
  language plpgsql
  volatile
  security definer
  set search_path = pg_catalog, public, pg_temp
as $$
begin
  with new_abilities_per_user_and_organization as (
    select
      m.user_id,
      m.organization_id,
      array(
        select distinct e
        from unnest(
          case 
          when m.is_owner then 
            NEW.owner_abilities || NEW.member_abilities || m.abilities
          else 
            NEW.member_abilities || m.abilities
          end
        ) as _(e)
        order by e
      ) as abilities
    from app_public.organization_memberships as m
    where m.organization_id = NEW.id
  )
  merge into app_hidden.user_abilities_per_organization as t
  using new_abilities_per_user_and_organization as s 
    on (t.organization_id = s.organization_id and t."user_id" = s."user_id")
  when matched and s.abilities is distinct from t.abilities then
    update set abilities = s.abilities;

  return new;
end
$$;

create trigger _800_refresh_user_abilities_per_organization
  after update of owner_abilities, member_abilities
  on app_public.organizations
  for each row
  execute function app_hidden.refresh_user_abilities_per_organization_on_update();

COMMIT;
