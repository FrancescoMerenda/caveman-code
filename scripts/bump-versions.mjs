#!/usr/bin/env bun
/**
 * Lockstep version bump across the monorepo — the bun replacement for
 * `npm version <inc> -ws --no-git-tag-version`.
 *
 * `bun pm version` only bumps the package in the current directory and has no
 * workspace flag, so this walks the root package.json plus every
 * packages/<name>/package.json and writes the same new version to all of them.
 * Dependency ranges between caveman-* packages are fixed up afterwards by
 * scripts/sync-versions.js (called by the version:* npm-scripts).
 *
 * Usage:
 *   bun scripts/bump-versions.mjs patch|minor|major|<explicit-version>
 */

import { readdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const increment = process.argv[2];

if (!increment) {
	console.error("usage: bun scripts/bump-versions.mjs patch|minor|major|<version>");
	process.exit(1);
}

function nextVersion(current, inc) {
	if (/^\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?$/.test(inc)) return inc;
	const match = /^(\d+)\.(\d+)\.(\d+)/.exec(current);
	if (!match) {
		console.error(`cannot parse current version "${current}"`);
		process.exit(1);
	}
	const [major, minor, patch] = match.slice(1).map(Number);
	switch (inc) {
		case "patch":
			return `${major}.${minor}.${patch + 1}`;
		case "minor":
			return `${major}.${minor + 1}.0`;
		case "major":
			return `${major + 1}.0.0`;
		default:
			console.error(`unknown increment "${inc}" (expected patch, minor, major, or an explicit version)`);
			process.exit(1);
	}
}

/** Root package.json is the source of truth for the current version. */
const manifestPaths = [join(repoRoot, "package.json")];
for (const entry of readdirSync(join(repoRoot, "packages"), { withFileTypes: true })) {
	if (!entry.isDirectory()) continue;
	const manifest = join(repoRoot, "packages", entry.name, "package.json");
	try {
		readFileSync(manifest);
		manifestPaths.push(manifest);
	} catch {
		// Not a package directory — skip.
	}
}

const rootVersion = JSON.parse(readFileSync(manifestPaths[0], "utf8")).version;
const target = nextVersion(rootVersion, increment);

for (const path of manifestPaths) {
	const raw = readFileSync(path, "utf8");
	const parsed = JSON.parse(raw);
	if (parsed.version === target) {
		console.log(`  = ${parsed.name ?? path}: already ${target}`);
		continue;
	}
	// Rewrite in place so formatting (tabs, key order) survives the bump.
	const updated = raw.replace(/("version"\s*:\s*)"[^"]+"/, `$1"${target}"`);
	if (updated === raw) {
		console.error(`failed to rewrite the version field in ${path}`);
		process.exit(1);
	}
	writeFileSync(path, updated);
	console.log(`  ✓ ${parsed.name ?? path}: ${parsed.version} → ${target}`);
}

console.log(`\nBumped to ${target} (${rootVersion} → ${target})`);
