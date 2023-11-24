import {config as loadConfig} from 'dotenv'
import findConfig from 'find-config'

const configPath = findConfig('.env')
if(!configPath) throw new Error('no .env found!')
loadConfig({ path: configPath })

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

//export default local as unknown as Config;

export const config: Config = {
  database: {
    rootUrl: process.env.ROOT_DATABASE_URL,
    host: process.env.DATABASE_HOST as string,
    name: process.env.DATABASE_NAME as string,
    roles: {
      owner: {
        username: process.env.DATABASE_OWNER as string,
        password: process.env.DATABASE_OWNER_PASSWORD as string
      },
      authenticator: {
        username: process.env.DATABASE_AUTHENTICATOR as string,
        password: process.env.DATABASE_AUTHENTICATOR_PASSWORD as string
      },
      visitor: {
        username: process.env.DATABASE_VISITOR as string
      }
    }
  }
} 

export default config