import { Task } from 'graphile-worker'

import { SendEmailPayload } from './send_email.js'

interface UserForgotPasswordPayload {
  /**
   * user id
   */
  id: string

  /**
   * email address
   */
  email: string

  /**
   * secret token
   */
  token: string
}

export const task: Task = async (inPayload, { addJob, withPgClient }) => {
  const payload: UserForgotPasswordPayload = inPayload as any
  const { id: userId, email, token } = payload
  const {
    rows: [user],
  } = await withPgClient((pgClient) =>
    pgClient.query(
      `
        select users.*
        from app_public.users
        where id = $1
      `,
      [userId]
    )
  )
  if (!user) {
    console.error('User not found; aborting')
    return
  }
  const sendEmailPayload: SendEmailPayload = {
    options: {
      to: email,
      subject: 'Passwort zurücksetzen',
    },
    template: 'password_reset.mjml',
    variables: {
      token,
      verifyLink: `${
        process.env.ROOT_URL
      }/reset-password?user_id=${encodeURIComponent(
        user.id
      )}&token=${encodeURIComponent(token)}`,
    },
  }
  await addJob('send_email', sendEmailPayload)
}

export default task
