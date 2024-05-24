// @ts-check
import globals from "globals";
import eslint from "@eslint/js";
import tseslint from "typescript-eslint";

export default tseslint.config(
  { languageOptions: { globals: globals.node } },
  eslint.configs.recommended,
  ...tseslint.configs.recommended
);
