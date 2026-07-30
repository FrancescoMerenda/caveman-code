#!/usr/bin/env bash
# 5-min smoke run of the CAVE Compression Proof.
# ~$0.15 on Haiku 4.5. Executes 3 tasks × {A-baseline, F-cave-full} × 1 seed.
# No output-eval. No headline publication; preflight still runs but over the
# smaller sample.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROOF_BENCH="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${PROOF_BENCH}/../../../.." && pwd)"

cd "${REPO_ROOT}"

if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
  echo "ANTHROPIC_API_KEY is required." >&2
  exit 2
fi

# Use the packaged cave binary if available; otherwise assume `cave` is on PATH.
if [[ -z "${CAVE_BIN:-}" ]]; then
  if [[ -x "${REPO_ROOT}/packages/coding-agent/dist/cli.js" ]]; then
    export CAVE_BIN="node ${REPO_ROOT}/packages/coding-agent/dist/cli.js"
  fi
fi

OUT_DIR="${OUT_DIR:-${PROOF_BENCH}/results/smoke-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "${OUT_DIR}"

echo "Running smoke suite → ${OUT_DIR}"
bun "${PROOF_BENCH}/run.ts" \
  --smoke \
  --max-cost 1 \
  --out-dir "${OUT_DIR}"
