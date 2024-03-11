-- Deploy 0814-cms:space-subscriptions/auto-subscribe-after-space-creation to pg
-- requires: space-subscriptions

BEGIN;

alter table app_public.organizations
  add column if not exists space_creator_abilities app_public.ability[] not null default '{manage}';

create or replace function app_hidden.auto_subscribe_after_space_creation()
  returns trigger
  language plpgsql
  volatile
  security definer
  set search_path = pg_catalog, public, pg_temp
as $$
declare
  my_user_id uuid := app_public.current_user_id();
  abilities_for_space_creators app_public.ability[];
begin
  select space_creator_abilities into abilities_for_space_creators
    from app_public.organizations
    where id = new.organization_id;

  if 
    my_user_id is not null 
    and array_length(abilities_for_space_creators, 1) > 0 
  then
    insert into app_public.space_subscriptions (space_id, subscriber_id, abilities)
      values (new.id, my_user_id, abilities_for_space_creators);
  end if;
  return new;
end
$$;

create trigger _500_auto_subscribe_after_space_creation
  after insert
  on app_public.spaces
  for each row
  execute function app_hidden.auto_subscribe_after_space_creation();

COMMIT;
