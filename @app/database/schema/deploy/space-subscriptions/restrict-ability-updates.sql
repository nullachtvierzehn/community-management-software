-- Deploy 0814-cms:space-subscriptions/restrict-ability-updates to pg
-- requires: abilities/add-grant-ability
-- requires: space-subscriptions
-- requires: users/view-for-space-abilities

BEGIN;

create or replace function app_hidden.restrict_ability_updates_on_space_subscriptions()
  returns trigger
  language plpgsql
  stable
  security definer
  set search_path = pg_catalog, public, pg_temp
as $$
declare
  my app_hidden.user_abilities_per_space;
  current_space app_public.spaces;
  added_abilities app_public.ability[] := array(
    select unnest(NEW.abilities) 
    except 
    select unnest(OLD.abilities)
  );
  categories_of_added_abilities app_public.ability[] := array(
    select distinct regexp_replace(
      unnest(added_abilities)::text, 
      '__.*$', 
      ''
    )::app_public.ability
  );
begin
  -- OK: New abilities are a subset of the old ones.
  if 
    new.space_id = old.space_id
    and new.subscriber_id = old.subscriber_id
    and (
      new.abilities is null 
      or new.abilities <@ OLD.abilities 
      or categories_of_added_abilities <@ OLD.abilities
    ) 
  then
    return new;
  end if;

  -- Fetch space
  select * into current_space 
  from app_public.spaces 
  where id = new.space_id;

  -- Fetch my abilities in this space.
  select * into my
  from app_hidden.user_abilities_per_space
  where 
    space_id = new.space_id
    and "user_id"= app_public.current_user_id();

  -- Handle my own subscriptions.
  if new.subscriber_id = app_public.current_user_id() then
    -- Right here, new abilities must be a superset of old abilities.
    -- (Otherwise, this function would already have returned.)
    -- Giving yourself abilities is only allowed if you already had the 'manage' ability.
    if not 'manage' = any (my.abilities) then
      raise exception 'You can''t give yourself any new abilities.' using errcode = 'DNIED';
    end if;
  -- Handle subscriptions of others.
  else
    -- Verify that I am allowed to grant the added abilities.
    if not (
      added_abilities <@ my.abilities_with_grant_option
      or categories_of_added_abilities <@ my.abilities_with_grant_option
    ) then
      raise exception 'You are not allowed to grant these abilities.' using errcode = 'DNIED';
    end if;
  end if;
  
  return new;
end
$$;


drop trigger if exists _900_restrict_ability_updates on app_public.space_subscriptions;

create trigger _900_restrict_ability_updates
  before update
  on app_public.space_subscriptions
  for each row
  when (
    old.abilities is distinct from new.abilities
    --and row_security_active('app_public.space_subscriptions')
  )
  execute function app_hidden.restrict_ability_updates_on_space_subscriptions(); 


COMMIT;
