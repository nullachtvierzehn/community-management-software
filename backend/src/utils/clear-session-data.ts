import { type SessionData } from "@fastify/secure-session";

export function clearSessionData(data?: SessionData) {
  if (!data) return;
  for (const prop of Object.getOwnPropertyNames(data)) {
    delete data[prop];
  }
}

export default clearSessionData;
