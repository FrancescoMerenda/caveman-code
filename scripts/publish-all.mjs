#!/usr/bin/env bun
/**
 * Publish every public workspace package — the bun replacement for
 * `npm publish -ws --access public`.
 *
 * `bun publish` publishes the package in the current directory only, so this
 * iterates packages/* in dependency order and skips anything marked private.
 * Each package's own prepublishOnly script still runs (bun honors it), same as
 * under npm.
 *
 * Usage:
 *   bun scripts/publish-all.mjs [--dry-run]
 */

import { spawnSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const dryRun = process.argv.includes("--dry-run");

/** Dependencies first, so a dependent never publishes against a missing version. */
const ORDER = ["tui", "ai", "agent", "coding-agent", "sdk", "markdown-preview", "mom", "web-ui", "pods"];

for (const name of ORDER) {
	const dir = join(repoRoot, "packages", name);
	const manifest = join(dir, "package.json");
	if (!existsSync(manifest)) continue;

	const pkg = JSON.parse(readFileSync(manifest, "utf8"));
	if (pkg.private) {
		console.log(`- skipping ${pkg.name} (private)`);
		continue;
	}

	const args = ["publish", "--access", "public"];
	if (dryRun) args.push("--dry-run");

	console.log(`\n> ${pkg.name}@${pkg.version}: bun ${args.join(" ")}`);
	const result = spawnSync("bun", args, { cwd: dir, stdio: "inherit" });
	if (result.error) {
		console.error(`failed to spawn bun: ${result.error.message}`);
		process.exit(1);
	}
	if (result.status !== 0) process.exit(result.status ?? 1);
}
