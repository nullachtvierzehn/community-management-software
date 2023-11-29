module.exports = {
  parser: 'vue-eslint-parser',
  root: true,
  extends: [
    // add more generic rulesets here, such as:
    // 'eslint:recommended',
    `${__dirname}/../../.eslintrc.cjs`,
    '@nuxt/eslint-config',
    'plugin:vue/vue3-recommended',
    'prettier',
  ],
  overrides: [
    {
      files: [`./pages/**/*.vue`],
      rules: {
        'vue/multi-word-component-names': 'off',
      },
    },
  ],
  rules: {
    'simple-import-sort/imports': 'error',
    'simple-import-sort/exports': 'error',
    'sort-imports': 'off',
    'import/order': 'off',
    'import/no-deprecated': 'warn',
    'import/no-duplicates': 'error',
    'vue/no-multiple-template-root': 'off',
  },
  parserOptions: {
    parser: '@typescript-eslint/parser',
    ecmaVersion: 2020,
    sourceType: 'module',
    ecmaFeatures: {
      jsx: true,
    },
  },
}
