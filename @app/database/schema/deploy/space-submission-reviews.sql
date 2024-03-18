-- Deploy 0814-cms:space-submission-reviews to pg
-- requires: space-submissions

BEGIN;

create type app_public.review_result as enum ('declined', 'commented', 'approved');

create table app_public.space_submission_reviews (
  space_submission_id uuid not null
    primary key
    constraint space_submission
      references app_public.space_submissions (id)
      on update cascade on delete cascade,
  reviewer_id uuid
    default app_public.current_user_id()
    constraint reviewer
      references app_public.users (id)
      on update cascade on delete set null,
  result app_public.review_result not null,
  comment text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table app_public.space_submission_reviews enable row level security;

grant select on app_public.space_submission_reviews to "$DATABASE_VISITOR";
grant insert (space_submission_id, reviewer_id, result, comment) on app_public.space_submission_reviews to "$DATABASE_VISITOR";
grant update (reviewer_id, result, comment) on app_public.space_submission_reviews to "$DATABASE_VISITOR";
grant delete on app_public.space_submission_reviews to "$DATABASE_VISITOR";


COMMIT;
