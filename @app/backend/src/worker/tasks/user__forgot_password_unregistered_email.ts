import { Task } from 'graphile-worker'

import { SendEmailPayload } from './send_email.js'

interface UserForgotPasswordUnregisteredEmailPayload {
  email: string
}

const projectName = 'test'

export const task: Task = async (inPayload, { addJob }) => {
  const payload: UserForgotPasswordUnregisteredEmailPayload = inPayload as any
  const { email } = payload

  const sendEmailPayload: SendEmailPayload = {
    options: {
      to: email,
      subject: `Password reset request failed: you don't have a ${projectName} account`,
    },
    template: 'password_reset_unregistered.mjml',
    variables: {
      url: process.env.ROOT_URL,
    },
  }
  await addJob('send_email', sendEmailPayload)
}

export default task
