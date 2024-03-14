-- Deploy 0814-cms:spaces to pg
-- requires: initial

BEGIN;

create table app_public.spaces (
  id uuid primary key
    default uuid_generate_v1mc(),
  organization_id uuid not null
    default app_public.current_user_first_member_organization_id()
    constraint organization
      references app_public.organizations (id)
      on update cascade on delete cascade,
  creator_id uuid
    default app_public.current_user_id()
    constraint creator
      references app_public.users (id)
      on update cascade on delete set null,
  "name" text not null,
  slug text not null
    constraint is_valid_slug
    check (slug ~ '^[a-zA-Z0-9_-]+$'),
  constraint unique_slug_per_organization
    unique nulls not distinct (organization_id, slug),
  is_public boolean not null default false,
  created_at timestamptz not null default current_timestamp,
  updated_at timestamptz not null default current_timestamp
);

alter table app_public.spaces enable row level security;

create index spaces_on_creator_id on app_public.spaces (creator_id);
create index spaces_on_created_at on app_public.spaces (created_at);
create index spaces_on_updated_at on app_public.spaces (updated_at);
create index spaces_on_organization_id on app_public.spaces (organization_id);

grant select on app_public.spaces to "$DATABASE_VISITOR";
grant insert (id, organization_id, creator_id, slug, "name", is_public) on app_public.spaces to "$DATABASE_VISITOR";
grant update (organization_id, slug, "name", is_public) on app_public.spaces to "$DATABASE_VISITOR";
grant delete on app_public.spaces to "$DATABASE_VISITOR";


-- auto-update updated_at
create trigger _200_timestamps
  before insert or update on app_public.spaces
  for each row
  execute procedure app_private.tg__timestamps();

COMMIT;
