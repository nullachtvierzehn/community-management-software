import { run } from "graphile-worker";

import { ownerPool } from "../database/pool.js";
import feed_invitations__send_invite from "./tasks/feed_invitations__send_invite.js";
import organization_invitations__send_invite from "./tasks/organization_invitations__send_invite.js";
import send_email from "./tasks/send_email.js";
import user__audit from "./tasks/user__audit.js";
import user__forgot_password from "./tasks/user__forgot_password.js";
import user__forgot_password_unregistered_email from "./tasks/user__forgot_password_unregistered_email.js";
import user__send_delete_account_email from "./tasks/user__send_delete_account_email.js";
import user_emails__send_verification from "./tasks/user_emails__send_verification.js";

// Run a worker to execute jobs:
export const runner = await run({
  pgPool: ownerPool,
  concurrency: 5,
  // Install signal handlers for graceful shutdown on SIGINT, SIGTERM, etc
  noHandleSignals: true,
  pollInterval: 1000,
  // you can set the taskList or taskDirectory but not both
  taskList: {
    feed_invitations__send_invite,
    organization_invitations__send_invite,
    send_email,
    user__audit,
    user__forgot_password,
    user__forgot_password_unregistered_email,
    user__send_delete_account_email,
    user_emails__send_verification,
  },
});

// Immediately await (or otherwise handle) the resulting promise, to avoid
// "unhandled rejection" errors causing a process crash in the event of
// something going wrong.
runner.promise
  .then(() => console.log("runner stopped"))
  .catch((error) => {
    console.error("runner stopped with error");
    console.error(error);
    process.exit(1);
  });

export default runner;

// If the worker exits (whether through fatal error or otherwise), the above
// promise will resolve/reject.
