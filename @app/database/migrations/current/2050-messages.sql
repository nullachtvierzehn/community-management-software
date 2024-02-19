create table app_public.message_revisions (
  -- two-column primary key with id and revision_id
  id uuid not null
    default uuid_generate_v1mc(),
  revision_id uuid not null 
    default uuid_generate_v1mc(),
  constraint message_revisions_pk
    primary key (id, revision_id),

  -- refer to parent revisions
  parent_revision_id uuid,
  constraint parent_revision
    foreign key (id, parent_revision_id)
    references app_public.message_revisions (id, revision_id)
    on update cascade on delete set null,
  
  -- editing user, might be different, depending on revision.
  editor_id uuid 
    default app_public.current_user_id()
    constraint editor
      references app_public.users (id)
      on update cascade on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- body
  "subject" text,
  body jsonb
);

create index message_revisions_on_created_at_within_id
  on app_public.message_revisions (id asc, created_at desc, revision_id desc);
create index message_revisions_on_id_and_parent_revision_id
  on app_public.message_revisions (id, parent_revision_id);

grant select on app_public.message_revisions to :DATABASE_VISITOR;
grant update ("subject", body) on app_public.message_revisions to :DATABASE_VISITOR;
grant insert (id, parent_revision_id, editor_id, "subject", body) on app_public.message_revisions to :DATABASE_VISITOR;
grant delete on app_public.message_revisions to :DATABASE_VISITOR;

create trigger _100_timestamps
  before insert or update on app_public.message_revisions
  for each row
  execute procedure app_private.tg__timestamps();


create or replace function app_hidden.rebase_message_revisions_before_deletion()
  returns trigger
  security definer
  language plpgsql
as $$
begin
  update app_public.message_revisions
    set parent_revision_id = old.parent_revision_id
    where 
      id = old.id 
      and parent_revision_id = old.revision_id;
  return old;
end
$$;

create trigger _200_rebase_message_revisions_before_deletion
  before delete
  on app_public.message_revisions
  for each row
  execute function app_hidden.rebase_message_revisions_before_deletion();

create or replace view app_public.active_message_revisions 
  with (security_invoker=true, security_barrier=true, check_option=cascaded) as 
  select tip.* 
  from app_public.message_revisions as tip
  where not exists (
    select 
    from app_public.message_revisions as child 
    where (tip.id, tip.revision_id) = (child.id, child.parent_revision_id)
  ); 

grant select on app_public.active_message_revisions to :DATABASE_VISITOR;
grant insert (id, parent_revision_id, editor_id, "subject", body) on app_public.active_message_revisions to :DATABASE_VISITOR;
grant update (editor_id, "subject", body) on app_public.active_message_revisions to :DATABASE_VISITOR;
grant delete on app_public.active_message_revisions to :DATABASE_VISITOR;

comment on view app_public.active_message_revisions is $$
  @primaryKey id,revision_id
  @foreignKey (editor_id) references app_public.users (id)
  $$;


create or replace view app_public.current_message_revisions
  with (security_invoker=true, security_barrier=true, check_option=cascaded) as 
  select tip.*
  from app_public.active_message_revisions as tip
  where (tip.created_at, tip.revision_id) >= all (
    select created_at, revision_id
    from app_public.active_message_revisions as others
    where tip.id = others.id
  );

comment on view app_public.current_message_revisions is $$
  @primaryKey id
  @foreignKey (editor_id) references app_public.users (id)
  $$;

grant select on app_public.current_message_revisions to :DATABASE_VISITOR;
grant insert (id, parent_revision_id, editor_id, "subject", body) on app_public.current_message_revisions to :DATABASE_VISITOR;
grant update (editor_id, "subject", body) on app_public.current_message_revisions to :DATABASE_VISITOR;
grant delete on app_public.current_message_revisions to :DATABASE_VISITOR;
