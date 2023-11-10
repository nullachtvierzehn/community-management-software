import { app } from "../app";
import "./login";
import "./registration";

export default app.get("/", async (request, reply) => {
  return { hello: "world" };
});
