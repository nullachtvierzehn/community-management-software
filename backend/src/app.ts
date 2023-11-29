import fastifyCookie from "@fastify/cookie";
import fastifySecureSession from "@fastify/secure-session";
import { JsonSchemaToTsProvider } from "@fastify/type-provider-json-schema-to-ts";
import fastifyWebsocket from "@fastify/websocket";
import fastify from "fastify";

import { dbPlugin } from "./database/fastify-plugin.js";
import { pool } from "./database/pool.js";
import validations from "./validations/index.js";

export const app = fastify({
  logger: true,
}).withTypeProvider<
  JsonSchemaToTsProvider<{ references: [typeof validations] }>
>();

app.addSchema(validations);
await app.register(fastifyWebsocket);
await app.register(fastifyCookie);
await app.register(fastifySecureSession, {
  key: Buffer.from(process.env.COOKIE_KEY as string, "hex"),
  cookie: {
    path: "/",
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
  },
});
await app.register(dbPlugin, { pool });

export default app;
