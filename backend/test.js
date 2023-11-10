"use strict";

const fastify = require("fastify")({ logger: false });
const fs = require("node:fs");
const path = require("node:path");

const key = fs.readFileSync(path.join(__dirname, "secret-key"));

console.log(key);

fastify.register(require("@fastify/secure-session"), {
  // the name of the attribute decorated on the request-object, defaults to 'session'
  sessionName: "session",
  // the name of the session cookie, defaults to value of sessionName
  cookieName: "my-session-cookie",
  // adapt this to point to the directory where secret-key is located
  key: key,
  cookie: {
    path: "/",
    // options for setCookie, see https://github.com/fastify/fastify-cookie
  },
});

fastify.post("/", (request, reply) => {
  request.session.set("data", request.body);

  // or when using a custom sessionName:
  request.customSessionName.set("data", request.body);

  reply.send("hello world");
});

fastify.get("/", (request, reply) => {
  const data = request.session.get("data");
  if (!data) {
    reply.code(404).send();
    return;
  }
  reply.send(data);
});

fastify.get("/ping", (request, reply) => {
  request.session.options({ maxAge: 3600 });

  // Send the session cookie to the client even if the session data didn't change
  // can be used to update cookie expiration
  request.session.touch();
  reply.send("pong");
});

fastify.post("/logout", (request, reply) => {
  request.session.delete();
  reply.send("logged out");
});
