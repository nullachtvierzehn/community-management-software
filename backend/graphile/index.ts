import { PostGraphileAmberPreset } from "postgraphile/presets/amber";
import { PgSimplifyInflectionPreset } from "@graphile/simplify-inflection";
import { makeV4Preset } from "postgraphile/presets/v4";
import { grafserv as buildGrafserv } from "grafserv/fastify/v4";

// import websocket from '@fastify/websocket'
// (Add any Fastify middleware you want here.)
// await app.register(websocket);
import postgraphile, { makeSchema } from "postgraphile";
import { makePgService } from "postgraphile/adaptors/pg";

import { pool, ownerPool } from "../database/pool";
import PassportLoginPlugin from "./plugins/PassportLoginPlugin";
import config from "../config";

export const preset: GraphileConfig.Preset = {
  extends: [
    PostGraphileAmberPreset,
    makeV4Preset({
      watchPg: true,
      allowExplain: true,
      graphiql: true,
      enhanceGraphiql: true,
      exportGqlSchemaPath: "./schema.graphql",
      sortExport: true,
    }),
    PgSimplifyInflectionPreset,
  ],
  plugins: [PassportLoginPlugin],
  grafast: {
    context(ctx, args) {
      const contextExtensions: Partial<Grafast.Context> = {
        rootPgPool: ownerPool,
        pgSettings: {
          // copy pgSettings that were already applied
          // https://postgraphile.org/postgraphile/next/config/#pgsettings
          ...args.contextValue?.pgSettings,
          role: config.database.roles.visitor.username,
        },
      };

      const { fastifyv4 } = ctx;
      if (fastifyv4) {
        const { request } = fastifyv4;
        contextExtensions.session = request.session;
        if (request.session.graphileSessionId)
          contextExtensions.pgSettings!["jwt.claims.session_id"] =
            request.session.graphileSessionId;
      }

      return contextExtensions;
    },
  },
  grafserv: {
    port: 3001,
    watch: true,
    websockets: true,
  },
  pgServices: [
    makePgService({
      pool,
      schemas: ["app_public"],
    }),
  ],
};

export const { schema, resolvedPreset } = await makeSchema(preset);

// Create a Grafserv instance
export const grafserv = buildGrafserv({ schema, preset });

export default grafserv;
