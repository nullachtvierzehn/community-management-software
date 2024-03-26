import fastifyCookie from '@fastify/cookie'
import fastifySecureSession from '@fastify/secure-session'
import { JsonSchemaToTsProvider } from '@fastify/type-provider-json-schema-to-ts'
import fastifyWebsocket from '@fastify/websocket'
import cookie from 'cookie'
import fastify from 'fastify'
import fastifyIO from 'fastify-socket.io'

import { dbPlugin } from './database/fastify-plugin.js'
import { pool } from './database/pool.js'
import validations from './validations/index.js'

export const app = fastify({
  logger: true,
}).withTypeProvider<JsonSchemaToTsProvider>()

app.addSchema(validations)

await Promise.all([
  app.register(fastifyIO.default, {
    allowEIO3: true,
  }),
  app.register(fastifyWebsocket, { options: { maxPayload: 1048576 } }),
  app.register(fastifyCookie),
  app.register(fastifySecureSession, {
    key: Buffer.from(process.env.COOKIE_KEY as string, 'hex'),
    cookie: {
      path: '/',
      httpOnly: true,
      sameSite: 'lax',
      secure: process.env.NODE_ENV === 'production',
    },
  }),
  app.register(dbPlugin, { pool }),
])

app.ready((error) => {
  if (error) throw error

  app.io.use((socket, next) => {
    // Parse session cookie and decrypt session data for every incoming socket
    if (!socket.handshake.headers.cookie) return next()
    const cookies = cookie.parse(socket.handshake.headers.cookie)
    if (!cookies.session) return next()
    const session = app.decodeSecureSession(cookies.session)
    if (!session) return next()
    const sessionData = session.data()
    if (!sessionData) return next()
    socket.session = { ...sessionData }
    next()
  })

  app.io.engine.on('connection_error', (err) => {
    console.error(err.code) // 3
    console.error(err.message) // "Bad request"
    console.error(err.context) // { name: 'TRANSPORT_MISMATCH', transport: 'websocket', previousTransport: 'polling' }
  })

  app.io.on('connection', (socket) => {
    console.info('socket connected', socket.id)
    socket.emit('hello')
    socket.on('disconnecting', (reason) => {
      console.info('socket disconnecting', reason)
    })
  })
})

app.get('/backend/ws', { websocket: true }, (socket, _request) => {
  console.log('connected', socket)
  socket.send('Ping')
  socket.on('message', (message) => {
    socket.send(`You said ${message}`)
    console.log('received', message)
  })
})

export default app
