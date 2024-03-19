import { Session, SessionData } from '@fastify/secure-session'
import { FileStore } from '@tus/file-store'
import { Server } from '@tus/server'
import { randomUUID } from 'crypto'
import { type PoolClient } from 'pg'

import { app } from '../app.js'
import config from '../config/index.js'
import { pool } from '../database/pool.js'

export const datastore = new FileStore({
  directory: process.env.UPLOAD_FOLDER as string,
})

declare module 'http' {
  interface IncomingMessage {
    session?: Session<SessionData> | null
  }
}

async function runAsUser<T>(
  session: Session<SessionData>,
  cb: (client: PoolClient) => Promise<T>
): Promise<T> {
  const client = await pool.connect()
  try {
    await client.query('BEGIN')
    await client.query(`SELECT set_config('jwt.claims.session_id', $1, true)`, [
      session.graphileSessionId,
    ])
    await client.query(
      `SET LOCAL ROLE ${config.database.roles.visitor.username}`
    )
    const result = await cb(client)
    await client.query('COMMIT')
    return result
  } catch (e) {
    await client.query('ROLLBACK')
    throw e
  } finally {
    client.release()
  }
}

export const server = new Server({
  path: '/backend/files',
  relativeLocation: true,
  respectForwardedHeaders: true,
  datastore,

  // for server api @see https://github.com/tus/tus-node-server/tree/main/packages/server
  // for examples @see https://github.com/tus/tus-node-server/tree/main/packages/server#example-integrate-tus-into-fastify
  namingFunction(_req) {
    return randomUUID()
  },
  async onIncomingRequest(req) {
    if (!req.session?.graphileSessionId) {
      throw { status_code: 401, body: 'Unauthorized' }
    }
  },
  async onUploadCreate(req, res, upload) {
    if (!req.session?.graphileSessionId) {
      throw { status_code: 401, body: 'Unauthorized' }
    }
    await runAsUser(req.session, async (client) => {
      await client.query(
        `INSERT INTO app_public.file_revisions (revision_id, "filename", mime_type, total_bytes) VALUES ($1, $2, $3, $4)`,
        [
          upload.id,
          upload.metadata?.filename,
          upload.metadata?.filetype,
          upload.size,
        ]
      )
    })
    return res
  },
  async onUploadFinish(req, res, upload) {
    if (!req.session?.graphileSessionId) {
      throw { status_code: 401, body: 'Unauthorized' }
    }
    await runAsUser(req.session, async (client) => {
      await client.query(
        'UPDATE app_public.file_revisions SET uploaded_bytes = $1 WHERE revision_id = $2',
        [upload.offset, upload.id]
      )
    })
    return res
  },
})

server.on('POST_RECEIVE', async (req, res, upload) => {
  if (!req.session?.graphileSessionId) {
    throw { status_code: 401, body: 'Unauthorized' }
  }
  await runAsUser(req.session, async (client) => {
    await client.query(
      'UPDATE app_public.file_revisions SET uploaded_bytes = $1 WHERE revision_id = $2',
      [upload.offset, upload.id]
    )
  })
  return res
})

/**
 * add new content-type to fastify forewards request
 * without any parser to leave body untouched
 * @see https://www.fastify.io/docs/latest/Reference/ContentTypeParser/
 * @see https://github.com/tus/tus-node-server/tree/main/packages/server#example-integrate-tus-into-fastify
 */
app.addContentTypeParser(
  'application/offset+octet-stream',
  (request, payload, done) => done(null)
)

app.get(
  '/backend/files/:id',
  {
    schema: {
      params: { type: 'object', properties: { id: { type: 'string' } } },
    },
  },
  async (req, reply) => {
    if (!req.session?.graphileSessionId) {
      return reply.status(401).send({ error: 'Unauthorized' })
    }

    if (!req.params.id) {
      return reply.status(404).send({ error: 'Not found' })
    }

    // Fetch file entry from the database.
    const file = await runAsUser(req.session, async (client) => {
      const {
        rows: [file],
      } = await client.query<{
        id: string
        total_bytes: number | null
        mime_type: string | null
      }>(
        'SELECT id, total_bytes, mime_type FROM app_public.file_revisions WHERE revision_id = $1',
        [req.params.id]
      )

      return file
    })

    if (!file) {
      return reply.status(404).send({ error: 'Not found in database' })
    }

    // Fetch file from disk.
    const stream = datastore.read(file.id)
    if (!stream) {
      return reply.status(404).send({ error: 'Not found in folder' })
    }

    return reply
      .status(200)
      .header('content-type', file.mime_type)
      .header('content-length', file.total_bytes)
      .send(stream)
  }
)

/**
 * let tus handle preparation and filehandling requests
 * Fastify exposes raw Node.js http req/res via .raw property
 * @see https://www.fastify.io/docs/latest/Reference/Request/
 * @see https://www.fastify.io/docs/latest/Reference/Reply/#raw
 */
app.all('/backend/files', (req, res) => {
  req.raw.session = req.session
  // TODO: replace only, if not in http or https
  req.headers['x-forwarded-proto'] = req.protocol ?? 'http'
  server.handle(req.raw, res.raw)
})

app.all('/backend/files/*', (req, res) => {
  req.raw.session = req.session
  // TODO: replace only, if not in http or https
  req.headers['x-forwarded-proto'] = req.protocol ?? 'http'
  server.handle(req.raw, res.raw)
})
