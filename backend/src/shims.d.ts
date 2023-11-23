import { type FastifySessionObject } from "@fastify/session";
import { type Pool } from "pg";

declare module "fastify" {
  interface Session {
    graphileSessionId?: string;
  }
}

declare global {
  namespace Grafast {
    interface Context {
      rootPgPool: Pool;
      session: FastifySessionObject;
    }
  }
}
