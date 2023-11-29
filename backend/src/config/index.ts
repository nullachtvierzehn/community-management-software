import { config as loadConfig } from "dotenv";
import findConfig from "find-config";

import { DeepPartial } from "../utils/deep-partial.js";

const configPath = findConfig(".env");
if (configPath) loadConfig({ path: configPath });

//import local from "./local.json" assert { type: "json" };

export interface DbRole {
  username: string;
  password?: string;
}

export interface Config {
  database: {
    rootUrl?: string;
    host: string;
    name: string;
    roles: {
      owner: DbRole;
      authenticator: DbRole;
      visitor: DbRole;
    };
  };
}

export function isValidConfig(
  particalConfig: DeepPartial<Config>
): particalConfig is Config {
  const missingProperties = [];
  if (!particalConfig.database) {
    missingProperties.push("database");
  } else {
    if (!particalConfig.database.host) missingProperties.push("database.host");
    if (!particalConfig.database.name) missingProperties.push("database.name");
    if (!particalConfig.database.roles) {
      missingProperties.push("database.roles");
    } else {
      if (!particalConfig.database.roles.authenticator) {
        missingProperties.push("database.roles.authenticator");
      } else {
        if (!particalConfig.database.roles.authenticator.username)
          missingProperties.push("database.roles.authenticator.username");
        if (!particalConfig.database.roles.authenticator.password)
          missingProperties.push("database.roles.authenticator.password");
      }
      if (!particalConfig.database.roles.owner) {
        missingProperties.push("database.roles.owner");
      } else {
        if (!particalConfig.database.roles.owner.username)
          missingProperties.push("database.roles.owner.username");
        if (!particalConfig.database.roles.owner.password)
          missingProperties.push("database.roles.owner.password");
      }
      if (!particalConfig.database.roles.visitor) {
        missingProperties.push("database.roles.visitor");
      } else {
        if (!particalConfig.database.roles.visitor.username)
          missingProperties.push("database.roles.visitor.username");
      }
    }
  }
  if (missingProperties.length > 0) {
    console.error("missing config attributes", missingProperties);
    return false;
  } else {
    return true;
  }
}

export const config: DeepPartial<Config> = {
  database: {
    rootUrl: process.env.ROOT_DATABASE_URL,
    host: process.env.DATABASE_HOST,
    name: process.env.DATABASE_NAME,
    roles: {
      owner: {
        username: process.env.DATABASE_OWNER,
        password: process.env.DATABASE_OWNER_PASSWORD,
      },
      authenticator: {
        username: process.env.DATABASE_AUTHENTICATOR,
        password: process.env.DATABASE_AUTHENTICATOR_PASSWORD,
      },
      visitor: {
        username: process.env.DATABASE_VISITOR,
      },
    },
  },
};

if (!isValidConfig(config)) throw new Error("invalid config");

export default config as Config;
