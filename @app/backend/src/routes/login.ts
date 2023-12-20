import { app } from '../app.js'
import { ownerPool } from '../database/pool.js'
import clearSessionData from '../utils/clear-session-data.js'
import loginSchema from '../validations/login-input.js'

export default app.post(
  '/login',
  { schema: { body: loginSchema } },
  async (request, reply) => {
    const { username, password } = request.body
    try {
      // Call our login function to find out if the username/password combination exists
      const {
        rows: [session],
      } = await ownerPool.query(
        `select sessions.* from app_private.login($1, $2) sessions where not (sessions is null)`,
        [username, password]
      )

      if (!session) {
        return reply
          .status(401)
          .send({ ok: false, error: 'Incorrect username/password' })
      }

      if (session.uuid) {
        clearSessionData(request.session.data())
        request.session.graphileSessionId = session.uuid
      }

      reply.status(200).send({ ok: true, sessionId: session.uuid })
    } catch (e: any) {
      const code = e.extensions?.code ?? e.code
      if (code === 'LOCKD') {
        return reply.status(401).send({
          ok: false,
          error:
            'User account locked - too many login attempts. Try again after 5 minutes.',
        })
      }
      const safeErrorCodes = ['LOCKD', 'CREDS']
      if (safeErrorCodes.includes(code)) {
        // TODO: throw SafeError
        throw e
      } else {
        console.error(e)
        throw Object.assign(new Error('Login failed'), {
          code,
        })
      }
    }
  }
)
