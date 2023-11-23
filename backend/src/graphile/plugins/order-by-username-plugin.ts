import {
  makeAddPgTableOrderByPlugin,
  orderByAscDesc,
} from "postgraphile/utils";
import { TYPES } from "@dataplan/pg";

export default makeAddPgTableOrderByPlugin(
  { schemaName: "app_public", tableName: "room_subscriptions" },
  ({ sql }) => {
    const sqlIdentifier = sql.identifier(Symbol("subscribersUsername"));
    return orderByAscDesc(
      "SUBSCRIBERS_USERNAME",
      ($select) => {
        const orderByFrag = sql`(
          select ${sqlIdentifier}.username
          from app_public.users as ${sqlIdentifier}
          where ${sqlIdentifier}.id = ${$select.alias}.subscriber_id
        )`;
        return { fragment: orderByFrag, codec: TYPES.citext };
      },
      { nulls: "last-iff-ascending" }
    );
  }
);
