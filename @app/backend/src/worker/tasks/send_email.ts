/*import {
  emailLegalText as legalText,
  fromEmail,
  projectName,
} from "@app/config";*/
import { Task } from 'graphile-worker'
import { htmlToText } from 'html-to-text'
import { template as lodashTemplate } from 'lodash-es'
import mjml2html from 'mjml'
import * as nodemailer from 'nodemailer'

import { templates } from '../../assets/templates/index.js'
import getTransport from '../transport.js'

declare module global {
  let TEST_EMAILS: any[]
}

global.TEST_EMAILS = []

const fromEmail = process.env.SMTP_USER
const projectName = 'test'
const legalText = 'sdfjksdfl'

const isTest = process.env.NODE_ENV === 'test'
const isDev = process.env.NODE_ENV !== 'production'

export interface SendEmailPayload {
  options: {
    from?: string
    to: string | string[]
    subject: string
  }
  template: string
  variables: {
    [varName: string]: any
  }
}

const task: Task = async (inPayload) => {
  const payload: SendEmailPayload = inPayload as any
  const transport = await getTransport()
  const { options: inOptions, template, variables } = payload
  const options = {
    from: fromEmail,
    ...inOptions,
  }
  if (template) {
    const html = loadTemplate(template, variables)
    const html2textableHtml = html.replace(/(<\/?)div/g, '$1p')
    const text = htmlToText(html2textableHtml, {
      wordwrap: 120,
    }).replace(/\n\s+\n/g, '\n\n')
    Object.assign(options, { html, text })
  }
  const info = await transport.sendMail(options)
  if (isTest) {
    global.TEST_EMAILS.push(info)
  } else if (isDev) {
    const url = nodemailer.getTestMessageUrl(info)
    if (url) {
      // Hex codes here equivalent to chalk.blue.underline
      console.log(
        `Development email preview: \x1B[34m\x1B[4m${url}\x1B[24m\x1B[39m`
      )
    }
  } else {
    console.log(`Mail sent: ${JSON.stringify(info)}`)
  }
}

export default task

function loadTemplate(template: string, variables: Record<string, any>) {
  const templateString = templates[template.replace('.mjml', '')]
  const templateFn = lodashTemplate(templateString, {
    escape: /\[\[([\s\S]+?)\]\]/g,
  })
  const mjml = templateFn({
    projectName,
    legalText,
    ...variables,
  })
  const { html, errors } = mjml2html(mjml)
  if (errors && errors.length) {
    console.error(errors)
  }
  return html
}
