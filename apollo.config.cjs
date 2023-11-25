module.exports = {
  client: {
    includes: [`${__dirname}/graphql/queries/**/*.graphql`],
    service: {
      name: "postgraphile",
      localSchemaFile: `${__dirname}/graphql/schema/schema.graphql`,
    },
  },
};
