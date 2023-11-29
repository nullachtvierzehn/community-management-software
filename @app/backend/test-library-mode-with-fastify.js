import fastify from 'fastify'
import { grafserv } from 'grafserv/fastify/v4'
import { makeSchema } from 'postgraphile'
import { makePgService } from 'postgraphile/adaptors/pg'
import { PostGraphileAmberPreset } from 'postgraphile/presets/amber'

/** @type {GraphileConfig.Preset} */
const preset = {
  extends: [PostGraphileAmberPreset],
  pgServices: [
    makePgService({
      connectionString: 'postgres://timo@localhost/app_cms',
      schemas: ['app_public'],
    }),
  ],
  gather: {
    pgStrictFunctions: true,
    installWatchFixtures: true,
  },
  grafserv: { watch: true, graphiql: true },
}

const { schema } = await makeSchema(preset)

export const app = fastify({
  logger: true,
})

// Create a Grafserv instance
const serv = grafserv({ schema, preset })

// Add the Grafserv instance's route handlers to the Fastify app
serv.addTo(app).catch((e) => {
  console.error(e)
  process.exit(1)
})

// Start the Fastify server
app.listen({ port: preset.grafserv?.port ?? 5678 }, (err, address) => {
  if (err) throw err
  console.log(`Server is now listening on ${address}`)
})
