module.exports = {
  client: {
    includes: [`${__dirname}/frontend/**/*.graphql`],
    service: {
      name: "postgraphile",
      localSchemaFile: `${__dirname}/backend/schema.graphql`,
    },
  },
};
