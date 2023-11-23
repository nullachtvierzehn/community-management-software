import { createServer } from "node:http";
import { PostGraphileAmberPreset } from "postgraphile/presets/amber";
import { makePgService } from "postgraphile/adaptors/pg";
import { grafserv } from "grafserv/express/v4";
import express from "express";
import { makeSchema } from "postgraphile";

// Create an express app
const app = express();

/** @type {GraphileConfig.Preset} */
const preset = {
  extends: [PostGraphileAmberPreset],
  pgServices: [
    makePgService({
      connectionString: "postgres://timo@localhost/app_cms",
      schemas: ["app_public"],
    }),
  ],
  gather: {
    pgStrictFunctions: true,
    installWatchFixtures: true,
  },
  grafserv: { watch: true, graphiql: true },
};

// Create a Node HTTP server, mounting Express into it
const server = createServer(app);
server.on("error", (e) => {
  console.error(e);
});

const { schema } = await makeSchema(preset);

// Create a Grafserv instance
const serv = grafserv({ schema, preset });

// Add the Grafserv instance's route handlers to the Express app, and register
// websockets if desired
serv.addTo(app, server).catch((e) => {
  console.error(e);
  process.exit(1);
});

// Start the Express server
server.listen(preset.grafserv?.port ?? 5678);
