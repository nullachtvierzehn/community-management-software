import local from "./local.json";

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

export default local as unknown as Config;
