import pg from "pg";
import config from "../config/index.js";

export const ownerPool = new pg.Pool({
  host: config.database.host,
  database: config.database.name,
  user: config.database.roles.owner.username,
  password: config.database.roles.owner!.password,
});

export const pool = new pg.Pool({
  host: config.database.host,
  database: config.database.name,
  user: config.database.roles.authenticator.username,
  password: config.database.roles.authenticator!.password,
});

export default pool;
