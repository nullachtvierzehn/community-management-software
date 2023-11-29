import { app } from '../app.js'
import { ownerPool } from '../database/pool.js'
import { ERROR_MESSAGE_OVERRIDES } from '../utils/handle-errors.js'

app.post(
  '/register',
  { schema: { body: { $ref: 'validations#/definitions/registrationInput' } } },
  async (request, reply) => {
    const { username, password, email, name, avatarUrl } = request.body
    try {
      // Create a user and create a session for it in the proccess
      const {
        rows: [{ user_id, session_id }],
      } = await ownerPool.query<{ user_id: number; session_id: string }>(
        `
          with new_user as (
            select users.* from app_private.really_create_user(
              username => $1,
              email => $2,
              email_is_verified => false,
              name => $3,
              avatar_url => $4,
              password => $5
            ) users where not (users is null)
          ), new_session as (
            insert into app_private.sessions (user_id)
            select id from new_user
            returning *
          )
          select new_user.id as user_id, new_session.uuid as session_id
          from new_user, new_session`,
        [username, email, name, avatarUrl, password]
      )

      if (!user_id) {
        throw Object.assign(new Error('Registration failed'), {
          code: 'FFFFF',
        })
      }

      if (session_id) {
        request.session.graphileSessionId = session_id
      }

      reply.status(201).send({
        userId: user_id,
        sessionId: session_id,
      })
    } catch (e: any) {
      const { code } = e
      const safeErrorCodes = [
        'WEAKP',
        'LOCKD',
        'EMTKN',
        ...Object.keys(ERROR_MESSAGE_OVERRIDES),
      ]
      if (safeErrorCodes.includes(code)) {
        throw e
      } else {
        console.error(
          'Unrecognised error in PassportLoginPlugin; replacing with sanitized version'
        )
        console.error(e)
        throw Object.assign(new Error('Registration failed'), {
          code,
        })
      }
    }
  }
)
