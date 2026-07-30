#!/usr/bin/env bun
/**
 * Copy the native runtime files that the compiled binary needs beside it.
 *
 * These cannot be embedded by `bun build --compile`:
 *   - photon_rs_bg.wasm — loaded from disk at runtime by @silvia-odwyer/photon-node
 *   - koffi            — externalized from the bundle (`--external koffi`) so the
 *                        binary does not carry all 18 platform .node files; only
 *                        the Windows build needs the module on disk.
 *
 * Paths are resolved through Node's resolver rather than hardcoded as
 * `node_modules/<pkg>/…`: bun installs into `node_modules/.bun/<pkg>@<ver>/…`
 * and does not flat-hoist transitive deps, so the literal path only ever
 * existed under npm.
 *
 * Usage:
 *   bun scripts/copy-binary-deps.mjs <destDir> [--koffi]
 */

import { copyFileSync, mkdirSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
// Resolve from the coding-agent package: that is where these deps are declared.
const require = createRequire(join(repoRoot, "packages", "coding-agent", "package.json"));

const [destArg, ...flags] = process.argv.slice(2);
if (!destArg) {
	console.error("usage: bun scripts/copy-binary-deps.mjs <destDir> [--koffi]");
	process.exit(1);
}
const dest = resolve(process.cwd(), destArg);
const withKoffi = flags.includes("--koffi");

function packageDir(packageName) {
	try {
		return dirname(require.resolve(`${packageName}/package.json`));
	} catch (err) {
		console.error(`[copy-binary-deps] cannot resolve ${packageName}: ${err.message}`);
		process.exit(1);
	}
}

mkdirSync(dest, { recursive: true });

const photonDir = packageDir("@silvia-odwyer/photon-node");
copyFileSync(join(photonDir, "photon_rs_bg.wasm"), join(dest, "photon_rs_bg.wasm"));
console.log(`[copy-binary-deps] photon_rs_bg.wasm -> ${dest}`);

if (withKoffi) {
	const koffiDir = packageDir("koffi");
	const koffiDest = join(dest, "node_modules", "koffi");
	const nativeDest = join(koffiDest, "build", "koffi", "win32_x64");
	mkdirSync(nativeDest, { recursive: true });
	copyFileSync(join(koffiDir, "index.js"), join(koffiDest, "index.js"));
	copyFileSync(join(koffiDir, "package.json"), join(koffiDest, "package.json"));
	copyFileSync(join(koffiDir, "build", "koffi", "win32_x64", "koffi.node"), join(nativeDest, "koffi.node"));
	console.log(`[copy-binary-deps] koffi (win32_x64) -> ${koffiDest}`);
}
