import { grafserv, preset } from "./graphile";
import { app } from "./app";

import "./routes";
import "./worker";

// Add the Grafserv instance's route handlers to the Fastify app
grafserv.addTo(app).catch((e) => {
  console.error(e);
  process.exit(1);
});

// Start the Fastify server
app.listen({ port: preset.grafserv?.port ?? 5678 }, (err, address) => {
  if (err) {
    app.log.error(err);
    process.exit(1);
  }
  console.log(`Server is now listening on ${address}`);
});
