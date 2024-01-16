import { promises as fsp } from 'fs'
import { memoize } from 'lodash-es'
import {
  createTestAccount,
  createTransport,
  type TestAccount,
} from 'nodemailer'

const { readFile, writeFile } = fsp

const etherealFilename = `${process.cwd()}/.ethereal`
const isTest = process.env.NODE_ENV === 'test'
const isDev = process.env.NODE_ENV !== 'production'

export async function getOrCreateTestAccount() {
  try {
    const testAccountJson = await readFile(etherealFilename, 'utf8')
    return JSON.parse(testAccountJson) as TestAccount
  } catch (e) {
    const account = await createTestAccount()
    await writeFile(etherealFilename, JSON.stringify(account))
    return account
  }
}

export const getTransport = memoize(async () => {
  if (isTest) {
    return createTransport({ jsonTransport: true })
  }

  if (isDev) {
    const account = await getOrCreateTestAccount()

    console.log(
      // Escapes equivalent to chalk.bold
      '\x1B[1m' +
        ' ✉️ Emails in development are sent via ethereal.email; your credentials follow:' +
        '\x1B[22m'
    )
    console.log('  Site:     https://ethereal.email/login')
    console.log(`  Username: ${account.user}`)
    console.log(`  Password: ${account.pass}`)

    return createTransport({
      host: 'smtp.ethereal.email',
      port: 587,
      secure: false,
      auth: {
        user: account.user,
        pass: account.pass,
      },
    })
  }

  return createTransport({
    from: `A-Friend-Team ${process.env.SMTP_USER}`,
    sender: process.env.SMTP_USER,
    host: process.env.SMTP_HOST,
    port: parseInt(process.env.SMTP_PORT ?? '587'),
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASSWORD,
    },
    tls: {
      rejectUnauthorized:
        process.env.SMTP_REJECT_UNAUTHORIZED_CERTS !== 'false',
    },
  })
})

export default getTransport
