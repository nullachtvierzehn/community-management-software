import fs from "fs";
import path from "path";

import fastify from "fastify";
import fastifySecureSession from "@fastify/secure-session";
import fastifyCookie from "@fastify/cookie";
import fastifyWebsocket from "@fastify/websocket";
import { JsonSchemaToTsProvider } from "@fastify/type-provider-json-schema-to-ts";

import { pool } from "./database/pool.js";
import { dbPlugin } from "./database/fastify-plugin.js";
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
