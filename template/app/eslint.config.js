import eslint from "@eslint/js";
import { defineConfig } from "eslint/config";
import globals from "globals";
import typescriptEslint from "typescript-eslint";

export default defineConfig(
  {
    ignores: ["dist/**", "public/sqlite/**"],
  },
  eslint.configs.recommended,
  typescriptEslint.configs.recommended,
  {
    files: ["src/**/*.ts"],
    languageOptions: {
      globals: globals.browser,
    },
  },
  {
    files: ["worker/**/*.ts"],
    languageOptions: {
      globals: globals.serviceworker,
    },
  },
  {
    files: ["tests/**/*.ts", "*.config.ts"],
    languageOptions: {
      globals: globals.node,
    },
  },
);
