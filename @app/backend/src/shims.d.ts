import {
  type Session as FastifySecureSession,
  type SessionData,
} from '@fastify/secure-session'
import { Client, type Defaults, type Pool } from 'pg'

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
