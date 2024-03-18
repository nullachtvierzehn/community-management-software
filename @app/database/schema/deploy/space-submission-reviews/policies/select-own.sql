-- Deploy 0814-cms:space-submission-reviews/policies/select-own to pg
-- requires: space-submission-reviews

BEGIN;

create policy select_own
  on app_public.space_submission_reviews
  for select
  to "$DATABASE_VISITOR"
  using (reviewer_id = app_public.current_user_id());

COMMIT;
