import accountActivity from './account_activity.mjml'
import deleteAccount from './delete_account.mjml'
import feedInvite from './feed_invite.mjml'
import organizationInvite from './organization_invite.mjml'
import passwordReset from './password_reset.mjml'
import passwordResetUnregistered from './password_reset_unregistered.mjml'
import roomItemNotification from './room_item_notification.mjml'
import verifyEmail from './verify_email.mjml'

export const templates = {
  account_activity: accountActivity,
  delete_account: deleteAccount,
  feed_invite: feedInvite,
  organization_invite: organizationInvite,
  password_reset_unregistered: passwordResetUnregistered,
  verify_email: verifyEmail,
  password_reset: passwordReset,
  room_item_notification: roomItemNotification,
} as Record<string, string | undefined>

export {
  accountActivity,
  deleteAccount,
  feedInvite,
  organizationInvite,
  passwordReset,
  passwordResetUnregistered,
  verifyEmail,
}
