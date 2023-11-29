module.exports = {
  client: {
    includes: [`${__dirname}/@app/graphql/queries/**/*.graphql`],
    service: {
      name: "postgraphile",
      localSchemaFile: `${__dirname}/@app/graphql/schema/schema.graphql`,
    },
  },
};
