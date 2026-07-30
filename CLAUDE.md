# CAVE CLI — caveman-cli

Minimal terminal coding agent + multi-provider LLM toolkit. TypeScript monorepo.

## Packages

| Package | CLI | Purpose |
|---------|-----|---------|
**v2 core (load-bearing):**
| `packages/coding-agent` | `caveman` | Coding agent: sessions, extensions, skills, themes, slash commands, subagents |
| `packages/ai` | `pi-ai` | Unified LLM API: OpenAI, Anthropic, Google, more |
| `packages/agent` | — | Agent runtime: tool calling, loop, state, system-prompt/toolFilter/maxTurns |
| `packages/tui` | — | Terminal UI: differential rendering, chord input, notifications |
| `packages/sdk` | — | `@juliusbrussee/caveman-sdk` — TS client for caveman-code daemon HTTP+WS API (openapi-generated) |
| `packages/markdown-preview` | — | Markdown renderer used by TUI |

**Out of scope for v2 (separate product surfaces, kept independent):**
| `packages/web-ui` | — | Web components for AI chat |
| `packages/mom` | `mom` | Slack bot → delegates to coding agent |
| `packages/pods` | `cave-pods` | vLLM deployment on GPU pods |

## Key Commands

```bash
bun install          # install all deps
bun run build        # build all packages
bun run lint         # biome lint
bun run format       # biome format
```

## Context Hierarchy

See `context/CLAUDE.md`. The active plan is `context/plans/cave-v2-best-in-class.md`.
Legacy CaveKit kits/plans/impl have been moved to `context/archive/`.

## Conventions

- Biome for lint/format (not ESLint/Prettier). Config: `biome.json`.
- TypeScript strict. Shared tsconfig: `tsconfig.base.json`.
- Package scope: `@juliusbrussee/caveman-*` (all packages on npm). Main CLI package: `@juliusbrussee/caveman-code`. Bin registers `caveman` AND `caveman-code` aliases.
- **bun is the package manager and script runner.** `bun.lock` is committed;
  there is no `package-lock.json`. No script may call `npm`/`npx` — the npm
  workspace verbs are replaced by `scripts/bump-versions.mjs` (version bump)
  and `scripts/publish-all.mjs` (publish). CI installs with
  `bun install --frozen-lockfile`.
- Node.js 20+ still required on PATH (tui tests run `node --test`, profiling
  scripts profile the Node runtime, published packages target Node).
- Every runtime import must be a declared dependency: bun does not flat-hoist
  transitive deps the way npm does, so an undeclared import that "worked"
  under npm fails to resolve under bun.

## Current State (2026-05-01)

- **No permission system.** Sandbox/permissions/approval-prompts stripped on
  branch `strip/permissions`. Caveman Code runs autopilot. Don't reintroduce. See
  memory `feedback_no_permissions`.
- **Plan mode wired.** `/plan` enters read-only chat mode (no edits, no shell
  writes); `/act` exits. Slash command at
  `packages/coding-agent/src/core/slash-commands/plan.ts`. Plan-mode gating
  also enforced inside the Task tool for spawned subagents.
- **Subagents.** Registry + `SendMessage` tool in coding-agent. Subagent
  isolation honored by Task tool. Agent definitions use `tool` constraints
  instead of removed `permissionMode` frontmatter.
- **AgentSession features:** checkpoints, repomap, chat mode, soft compaction,
  hooks, MCP, skills, recipes, `/clear`, `/quick-open`, `/task-list`.
- **Goal loop (in-flight, untracked):**
  `packages/coding-agent/src/core/goal-loop/` — `goal-runner`, `goal-state`,
  `goal-prompts`. Not yet committed; dev work on `strip/permissions`.
- **Anthropic model list self-updates.** `packages/ai/src/models.generated.ts`
  is refreshed daily by `.github/workflows/auto-update-models.yml`, and at
  runtime `providers/anthropic-discovery.ts` registers every id returned by
  `GET /v1/models` into the in-memory registry — so a model released after the
  installed build still shows up in the picker. New ids get list pricing
  inferred from their tier (haiku/sonnet/opus); known ids keep generated
  pricing.
- **Walkthrough doc:** `context/notes/agent-loop-walkthrough.md` traces the
  full path from `caveman` boot → `interactive-mode` dispatch → `session.prompt`
  → `agent-loop.runLoop`. Read this first when touching the loop.

## Agent Guidance

- Read package-specific CLAUDE.md before touching that package.
- Before building from scratch, run the **pi-check**: search `pi-code` upstream,
  the `pi-*` npm scope, and pi extensions for an existing module. Vendor or wrap
  if found. Note "borrowed from pi: <name>" in the deliverable. See plan §0.
- CaveKit (`@juliusbrussee/caveman-cavekit`) has been removed; replaced by plan mode (read-only
  exploration), markdown skills, and recipes.
- Don't add per-file "inspired by hermes-agent" attribution comments even when
  a plan/kit suggests it (memory `feedback_no_hermes_inspired_comment`).
