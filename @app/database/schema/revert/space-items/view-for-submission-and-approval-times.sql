-- Revert 0814-cms:space-items/view-for-submission-and-approval-times from pg

BEGIN;

drop view app_public.space_item_submission_and_approval_times;

drop view app_hidden.space_item_submission_and_approval_times;

COMMIT;
