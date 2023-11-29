import fastify, {
  FastifyInstance,
  FastifyPluginAsync,
  FastifyReply,
  FastifyRequest,
} from "fastify";
import { Pool, PoolClient } from "pg";

declare module "fastify" {
  interface FastifyRequest {
    pgClient: PoolClient | null;
  }
}

// Define a plugin to manage database transactions
export const dbPlugin: FastifyPluginAsync<{ pool: Pool }> = async (
  fastify,
  options
) => {
  const { pool } = options;

  fastify.decorateRequest("pgClient", null);

  fastify.addHook("preHandler", async (request, reply) => {
    const client = await pool.connect();
    request.pgClient = client;
    await client.query("BEGIN");
  });

  fastify.addHook("onError", async (request, reply, error) => {
    if (request.pgClient) {
      try {
        await request.pgClient.query("ROLLBACK");
      } finally {
        request.pgClient.release();
      }
    }
  });

  fastify.addHook("onSend", async (request, reply, payload) => {
    if (request.pgClient) {
      try {
        if (reply.statusCode >= 200 && reply.statusCode < 400) {
          await request.pgClient.query("COMMIT");
        } else {
          await request.pgClient.query("ROLLBACK");
        }
      } catch (error) {
        // If there's an error committing the transaction, we modify the response to indicate failure
        reply.code(500).send({
          error: "Internal Server Error",
          message: "Failed to commit transaction",
          details: JSON.stringify(error),
        });
      } finally {
        request.pgClient.release();
      }
    }
    return payload; // Return the original payload, unless it was modified due to a commit error
  });
};

export default dbPlugin;
