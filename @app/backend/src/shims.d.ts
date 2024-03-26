import {
  type Session as FastifySecureSession,
  type SessionData,
} from '@fastify/secure-session'
import { Client, type Defaults, type Pool } from 'pg'
import { type Server } from 'socket.io'

export { Client, Defaults }

declare module '@fastify/secure-session' {
  interface SessionData {
    graphileSessionId?: string
  }
}

declare global {
  namespace Grafast {
    interface Context {
      rootPgPool: Pool
      session: FastifySecureSession<SessionData>
    }
  }
}

declare module 'fastify' {
  interface FastifyInstance {
    io: Server<{ hello: () => void }>
  }
}

declare module 'socket.io' {
  interface Socket {
    session?: SessionData | null
  }
}
