module.exports = {
  client: {
    includes: [`${__dirname}/graphql-queries/**/*.graphql`],
    service: {
      name: "postgraphile",
      localSchemaFile: `${__dirname}/backend/schema.graphql`,
    },
  },
};
