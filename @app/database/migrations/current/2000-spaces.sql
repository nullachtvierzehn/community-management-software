

create table app_public.spaces (
  id uuid primary key default uuid_generate_v1mc(),
  "name" text,
  is_public boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

grant select on app_public.spaces to :DATABASE_VISITOR;



do $$
begin
  if exists(
    select 1
      from information_schema.columns
      where table_schema = 'app_public'
      and table_name = 'topics'
      and column_name = 'title'
  ) then
    alter table app_public.topics
      rename column title to "name";
  end if;
end$$;

do $$
begin
  if exists(
    select 1
      from information_schema.columns
      where table_schema = 'app_public'
      and table_name = 'files'
      and column_name = 'filename'
  ) then
    alter table app_public.files
      rename column "filename" to "name";
  end if;
end$$;

create type app_public.space_item as (
  id uuid,
  created_at timestamptz,
  updated_at timestamptz
);

comment on type app_public.space_item is $$
  @interface mode:union
  @name SpaceItemEntity
  $$;

grant usage on type app_public.space_item to :DATABASE_VISITOR;


comment on table app_public.spaces is $$
  @implements SpaceItemEntity
  A space is a place where users meet and interact with items.
  $$;

comment on table app_public.topics is $$
  @implements SpaceItemEntity
  A topic is a short text about something. Most topics should have the scope of a micro learning unit.
  $$;

comment on table app_public.files is $$
  @implements SpaceItemEntity
  A file stored on the system.
  $$;

