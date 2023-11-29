module.exports = {
  parser: "vue-eslint-parser",
  extends: [
    // add more generic rulesets here, such as:
    // 'eslint:recommended',
    `${__dirname}/../../.eslintrc.cjs`,
    "@nuxt/eslint-config",
    "plugin:vue/vue3-recommended",
  ],
  overrides: [
    {
      files: [`./pages/**/*.vue`],
      rules: {
        "vue/multi-word-component-names": "off",
      },
    },
  ],
  rules: {
    "vue/no-multiple-template-root": "off"
  },
  parserOptions: {
    parser: "@typescript-eslint/parser",
    ecmaVersion: 2020,
    sourceType: "module",
    ecmaFeatures: {
      jsx: true,
    },
  },
};
