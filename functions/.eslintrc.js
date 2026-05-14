module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
    "plugin:import/errors",
    "plugin:import/warnings",
    "plugin:import/typescript",
    "plugin:@typescript-eslint/recommended",
  ],
  parser: "@typescript-eslint/parser",
  parserOptions: {
    project: ["tsconfig.json", "tsconfig.dev.json"],
    sourceType: "module",
  },
  ignorePatterns: [
    "/lib/**/*", // Ignore built files.
    "/generated/**/*", // Ignore generated files.
    "videoSeo.js",
  ],
  plugins: [
    "@typescript-eslint",
    "import",
  ],
  rules: {
    "quotes": 0,
    "import/no-unresolved": 0,
    "indent": 0,
    "linebreak-style": 0,
    "max-len": 0,
    "object-curly-spacing": 0,
    "no-trailing-spaces": 0,
    "comma-dangle": 0,
    "eol-last": 0,
    "@typescript-eslint/no-non-null-assertion": 0,
    "no-multi-spaces": 0,
    "operator-linebreak": 0,
    "no-case-declarations": 0,
    "no-constant-condition": 0,
    "camelcase": 0,
    "require-jsdoc": 0,
    "valid-jsdoc": 0,
    "padded-blocks": 0,
    "@typescript-eslint/no-explicit-any": 0,
    "@typescript-eslint/no-unused-vars": 0,
    "@typescript-eslint/no-empty-function": 0,
    "@typescript-eslint/ban-ts-comment": 0,
    "no-empty": 0,
  },
};
