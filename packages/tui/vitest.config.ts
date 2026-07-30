import { defineConfig } from "vitest/config";

export default defineConfig({
	test: {
		// Most tui tests use node:test and run under `node --test` (see the
		// package "test" script). Only files under test/vitest/ use the vitest
		// API, so neither runner picks up the other's files.
		include: ["test/vitest/**/*.test.ts"],
	},
});
