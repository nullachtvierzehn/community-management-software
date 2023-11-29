import {
  type Session as FastifySecureSession,
  type SessionData,
} from "@fastify/secure-session";
import { type Pool } from "pg";

declare module "@fastify/secure-session" {
  interface SessionData {
    graphileSessionId?: string;
  }
}

declare global {
  namespace Grafast {
    interface Context {
      rootPgPool: Pool;
      session: FastifySecureSession<SessionData>;
    }
  }
}
