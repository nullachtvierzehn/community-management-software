create type app_public.submittable_entity as (
  id uuid,
  created_at timestamptz,
  updated_at timestamptz
);

grant usage on type app_public.submittable_entity to :DATABASE_VISITOR;

comment on type app_public.submittable_entity is $$
  @interface mode:union
  @name SubmittableEntity
  $$;


comment on table app_public.spaces is $$
  @implements SubmittableEntity
  A space is a place where users meet and interact with items.
  $$;

comment on table app_public.topics is $$
  @implements SubmittableEntity
  A topic is a short text about something. Most topics should have the scope of a micro learning unit.
  $$;

comment on table app_public.files is $$
  @implements SubmittableEntity
  A file stored on the system.
  $$;