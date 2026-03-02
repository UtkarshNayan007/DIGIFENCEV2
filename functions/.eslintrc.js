module.exports = {
    root: true,
    env: {
        es2022: true,
        node: true,
        jest: true,
    },
    extends: ["eslint:recommended"],
    parserOptions: {
        ecmaVersion: 2022,
    },
    rules: {
        "no-unused-vars": ["warn", { argsIgnorePattern: "^_" }],
    },
};
