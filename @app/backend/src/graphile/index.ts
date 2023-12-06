import { PgSimplifyInflectionPreset } from '@graphile/simplify-inflection'
// import websocket from '@fastify/websocket'
// (Add any Fastify middleware you want here.)
// await app.register(websocket);
import { postgraphile } from 'postgraphile'
import { makePgService } from 'postgraphile/adaptors/pg'
import { grafserv } from 'postgraphile/grafserv/fastify/v4'
import { PostGraphileAmberPreset } from 'postgraphile/presets/amber'
import { makeV4Preset } from 'postgraphile/presets/v4'
import { PostGraphileConnectionFilterPreset } from 'postgraphile-plugin-connection-filter'

import config from '../config/index.js'
import { ownerPool, pool } from '../database/pool.js'
import OrderByUsernamePlugin from './plugins/order-by-username-plugin.js'
import PassportLoginPlugin from './plugins/PassportLoginPlugin.js'

// https://www.postgraphile.org/postgraphile/next/config
export const preset: GraphileConfig.Preset = {
  extends: [
    PostGraphileAmberPreset,
    makeV4Preset({
      watchPg: true,
      subscriptions: true,
      dynamicJson: true,
      setofFunctionsContainNulls: false,
      ignoreRBAC: false,
      allowExplain: true,
      graphiql: true,
      enhanceGraphiql: true,
      //exportGqlSchemaPath: "./schema.graphql",
      //sortExport: true,
    }),

    // adds `filter` to all queries
    PostGraphileConnectionFilterPreset,

    // simplifies field names
    PgSimplifyInflectionPreset,
  ],
  plugins: [
    /*PgIntrospectionPlugin,*/ PassportLoginPlugin,
    OrderByUsernamePlugin,
  ],
  gather: {
    pgStrictFunctions: true,
    installWatchFixtures: true,
  },
  schema: {
    retryOnInitFail: true,
    exportSchemaSDLPath: '../../@app/graphql/schema/schema.graphql',
    exportSchemaIntrospectionResultPath:
      '../../@app/graphql/schema/schema.json',
    sortExport: true,
  },
  grafast: {
    async context(ctx, args) {
      const contextExtensions: Partial<Grafast.Context> = {
        rootPgPool: ownerPool,
        pgSettings: {
          // copy pgSettings that were already applied
          // https://postgraphile.org/postgraphile/next/config/#pgsettings
          ...args.contextValue?.pgSettings,
          role: config.database.roles.visitor.username,
        },
      }

      const { fastifyv4 } = ctx
      if (fastifyv4) {
        const {
          request: { session },
        } = fastifyv4
        contextExtensions.session = session
        if (session.graphileSessionId) {
          contextExtensions.pgSettings!['jwt.claims.session_id'] =
            session.graphileSessionId
          // Update the last_active timestamp (but only do it at most once every 15 seconds to avoid too much churn).
          await ownerPool.query(
            "UPDATE app_private.sessions SET last_active = NOW() WHERE uuid = $1 AND last_active < NOW() - INTERVAL '15 seconds'",
            [session.graphileSessionId]
          )
        }
      }

      return contextExtensions
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
      superuserConnectionString: config.database.rootUrl,
      schemas: ['app_public'],
    }),
  ],
}

export const postgraphileInstance = postgraphile(preset)
export const grafservInstance = postgraphileInstance.createServ(grafserv)
export default grafservInstance
