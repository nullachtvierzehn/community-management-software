import fs from "fs";
import path from "path";

import fastify from "fastify";
import fastifySession from "@fastify/session";
import fastifyCookie from "@fastify/cookie";
import fastifyWebsocket from "@fastify/websocket";
import { JsonSchemaToTsProvider } from "@fastify/type-provider-json-schema-to-ts";

import { pool } from "./database/pool";
import { dbPlugin } from "./database/fastify-plugin";
import validations from "./validations";

export const app = fastify({
  logger: true,
}).withTypeProvider<
  JsonSchemaToTsProvider<{ references: [typeof validations] }>
>();

app.addSchema(validations);
await app.register(fastifyWebsocket);
await app.register(fastifyCookie);
await app.register(fastifySession, {
  secret: "the secret must have length 32 or greater",
  cookieName: "session",
  cookie: {
    path: "/",
    httpOnly: true,
    secure: "auto",
    sameSite: "lax",
  },
});
await app.register(dbPlugin, { pool });

export default app;
