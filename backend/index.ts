import fastify from 'fastify';
import { PostGraphileAmberPreset } from "postgraphile/presets/amber";
import { PgSimplifyInflectionPreset } from "@graphile/simplify-inflection";
import { makeV4Preset } from "postgraphile/presets/v4";
import { grafserv } from "grafserv/fastify/v4";


// import websocket from '@fastify/websocket'
import postgraphile, { makeSchema } from 'postgraphile';
import { makePgService } from 'postgraphile/adaptors/pg';



// Create a Fastify app
const app = fastify({
  logger: true,
});
// (Add any Fastify middleware you want here.)
// await app.register(websocket);


const preset: GraphileConfig.Preset =  {
  extends: [
    PostGraphileAmberPreset,
    makeV4Preset({
      allowExplain: true,
      graphiql: true,
      enhanceGraphiql: true,
    }),
    PgSimplifyInflectionPreset
  ],
  grafserv: { port: 3001, watch: true },
  pgServices: [
    makePgService({
      connectionString: "postgres:///blub",
      schemas: ["public"]
    })
  ]
}

const { schema, resolvedPreset } = await makeSchema(preset)

// Create a Grafserv instance
const serv = grafserv({ schema, preset });

// Add the Grafserv instance's route handlers to the Fastify app
serv.addTo(app).catch((e) => {
  console.error(e);
  process.exit(1);
});

app.get('/', async (request, reply) => {
  return { hello: 'world' };
});

// Start the Fastify server
app.listen({ port: preset.grafserv?.port ?? 5678 }, (err, address) => {
  if (err) {
    app.log.error(err)
    process.exit(1)
  }
  console.log(`Server is now listening on ${address}`);
});
