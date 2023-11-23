import { app } from "../app.js";
import "./login.js";
import "./registration.js";

export default app.get("/", async (request, reply) => {
  return { hello: "world" };
});
