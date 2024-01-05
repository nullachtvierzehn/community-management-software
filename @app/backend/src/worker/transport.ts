import { promises as fsp } from 'fs'
import * as nodemailer from 'nodemailer'
import SMTPTransport from 'nodemailer/lib/smtp-transport/index.js'

const { readFile, writeFile } = fsp

const smtp: SMTPTransport.Options = {
  from: `A-Friend-Team ${process.env.SMTP_USER}`,
  sender: process.env.SMTP_USER,
  host: process.env.SMTP_HOST,
  port: parseInt(process.env.SMTP_PORT ?? '587'),
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASSWORD,
  },
  tls: {
    rejectUnauthorized: process.env.SMTP_REJECT_UNAUTHORIZED_CERTS !== 'false',
  },
} // originally from @app/config
const isTest = process.env.NODE_ENV === 'test'
const isDev = process.env.NODE_ENV !== 'production'

let transporterPromise: Promise<nodemailer.Transporter>
const etherealFilename = `${process.cwd()}/.ethereal`

let logged = false

export default function getTransport(): Promise<nodemailer.Transporter> {
  if (!transporterPromise) {
    transporterPromise = (async () => {
      if (isTest) {
        return nodemailer.createTransport({
          jsonTransport: true,
        })
      } else if (isDev) {
        let account
        try {
          const testAccountJson = await readFile(etherealFilename, 'utf8')
          account = JSON.parse(testAccountJson)
        } catch (e: any) {
          account = await nodemailer.createTestAccount()
          await writeFile(etherealFilename, JSON.stringify(account))
        }
        if (!logged) {
          logged = true
          console.log()
          console.log()
          console.log(
            // Escapes equivalent to chalk.bold
            '\x1B[1m' +
              ' ✉️ Emails in development are sent via ethereal.email; your credentials follow:' +
              '\x1B[22m'
          )
          console.log('  Site:     https://ethereal.email/login')
          console.log(`  Username: ${account.user}`)
          console.log(`  Password: ${account.pass}`)
          console.log()
          console.log()
        }
        return nodemailer.createTransport({
          host: 'smtp.ethereal.email',
          port: 587,
          secure: false,
          auth: {
            user: account.user,
            pass: account.pass,
          },
        })
      } else {
        if (smtp) {
          const transport = nodemailer.createTransport(smtp)
          return transport
        } else {
          throw new Error('setup stmp transport')
        }
      }
    })()
  }
  return transporterPromise!
}
