#!/usr/bin/env bash
# Full CAVE Compression Proof run.
# ~$2-3 on Haiku 4.5, capped hard at $5 via --max-cost.
# 4 configs × 10 tasks × 2 seeds = 80 live runs + 120 output-eval gens + 120 judge calls.
# Produces results.md (publishable), results.json, waterfall.txt under results/<timestamp>/.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROOF_BENCH="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${PROOF_BENCH}/../../../.." && pwd)"

cd "${REPO_ROOT}"

if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
  echo "ANTHROPIC_API_KEY is required." >&2
  exit 2
fi

if [[ -z "${CAVE_BIN:-}" ]]; then
  if [[ -x "${REPO_ROOT}/packages/coding-agent/dist/cli.js" ]]; then
    export CAVE_BIN="node ${REPO_ROOT}/packages/coding-agent/dist/cli.js"
  fi
fi

MAX_COST="${MAX_COST:-5}"
OUT_DIR="${OUT_DIR:-${PROOF_BENCH}/results/$(date +%Y%m%d-%H%M%S)}"
mkdir -p "${OUT_DIR}"

echo "Running full suite → ${OUT_DIR}  (max-cost=\$${MAX_COST})"
bun "${PROOF_BENCH}/run.ts" \
  --max-cost "${MAX_COST}" \
  --out-dir "${OUT_DIR}"
