const { readFileSync } = require('fs')
const schemaString = readFileSync(
  `${__dirname}/@app/graphql/schema/schema.graphql`,
  'utf8'
)

module.exports = {
  root: true,
  parser: '@typescript-eslint/parser',
  extends: [
    'plugin:import/errors',
    'plugin:import/typescript',
    'eslint:recommended',
    'prettier',
  ],
  plugins: [
    'jest',
    '@typescript-eslint',
    'graphql',
    'simple-import-sort',
    'import',
    'prettier',
  ],
  parserOptions: {
    ecmaVersion: 2021,
    sourceType: 'module',
    ecmaFeatures: {
      jsx: true,
    },
  },
  settings: {
    // helps eslint to validate imports, if they involve a path alias from tsconfig.json
    'import/resolver': {
      typescript: {
        // for options: https://www.npmjs.com/package/eslint-import-resolver-typescript
        alwaysTryTypes: true,
        project: ['@app/*/tsconfig.json', '@app/frontend/.nuxt/tsconfig.json'],
      },
    },
  },
  env: {
    browser: true,
    node: true,
    jest: true,
    es2020: true,
  },
  overrides: [
    {
      files: ['*.ts'],
      rules: {
        'no-undef': 'off',
      },
    },
  ],
  rules: {
    'prettier/prettier': 'warn',
    '@typescript-eslint/no-unused-vars': [
      'error',
      {
        argsIgnorePattern: '^_',
        varsIgnorePattern: '^_',
        args: 'after-used',
        ignoreRestSiblings: true,
      },
    ],
    'no-unused-vars': [
      'error',
      {
        ignoreRestSiblings: true,
        varsIgnorePattern: '^_',
        argsIgnorePattern: '^_',
        destructuredArrayIgnorePattern: '^_',
        caughtErrorsIgnorePattern: '^ignore',
      },
    ],
    'no-unused-expressions': [
      'error',
      {
        allowTernary: true,
      },
    ],
    'no-console': 0,
    'no-confusing-arrow': 0,
    'no-else-return': 0,
    'no-return-assign': [2, 'except-parens'],
    'no-underscore-dangle': 0,
    'jest/no-focused-tests': 2,
    'jest/no-identical-title': 2,
    camelcase: 0,
    'prefer-arrow-callback': [
      'error',
      {
        allowNamedFunctions: true,
      },
    ],
    'class-methods-use-this': 0,
    'no-restricted-syntax': 0,
    'no-param-reassign': [
      'error',
      {
        props: false,
      },
    ],
    'react/prop-types': 0,
    'react/no-multi-comp': 0,
    'react/jsx-filename-extension': 0,
    'react/no-unescaped-entities': 0,

    'import/no-extraneous-dependencies': 0,

    'graphql/template-strings': [
      'error',
      {
        env: 'literal',
        schemaString,
        validators: [
          'ExecutableDefinitions',
          'FieldsOnCorrectType',
          'FragmentsOnCompositeTypes',
          'KnownArgumentNames',
          'KnownDirectives', // disabled by default in relay
          // "KnownFragmentNames", // disabled by default in all envs
          'KnownTypeNames',
          'LoneAnonymousOperation',
          'NoFragmentCycles',
          'NoUndefinedVariables', //disabled by default in relay
          // "NoUnusedFragments" // disabled by default in all envs
          // "NoUnusedVariables" throws even when fragments use the variable
          'OverlappingFieldsCanBeMerged',
          'PossibleFragmentSpreads',
          'ProvidedRequiredArguments', // disabled by default in relay
          'ScalarLeafs', // disabled by default in relay
          'SingleFieldSubscriptions',
          'UniqueArgumentNames',
          'UniqueDirectivesPerLocation',
          'UniqueFragmentNames',
          'UniqueInputFieldNames',
          'UniqueOperationNames',
          'UniqueVariableNames',
          'ValuesOfCorrectType',
          'VariablesAreInputTypes',
          // "VariablesDefaultValueAllowed",
          'VariablesInAllowedPosition',
        ],
      },
    ],
    'graphql/named-operations': [
      'error',
      {
        schemaString,
      },
    ],
    'graphql/required-fields': [
      'error',
      {
        env: 'literal',
        schemaString,
        requiredFields: ['nodeId', 'id'],
      },
    ],
    'react/destructuring-assignment': 0,

    'arrow-body-style': 0,
    'no-nested-ternary': 0,

    /*
     * simple-import-sort seems to be the most stable import sorting currently,
     * disable others
     */
    'simple-import-sort/imports': 'error',
    'simple-import-sort/exports': 'error',
    'sort-imports': 'off',
    'import/order': 'off',

    'import/no-deprecated': 'warn',
    'import/no-duplicates': 'error',
  },
}
