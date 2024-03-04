

create table app_public.spaces (
  id uuid primary key default uuid_generate_v1mc(),
  "name" text,
  is_public boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

grant select, insert, update, delete on app_public.spaces to :DATABASE_VISITOR;
