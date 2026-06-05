#!/usr/bin/env bash
#
# Checks this machine can build and test the generated TypeScript project before
# you run scripts/init.sh (POSIX counterpart of check-env.ps1 — use whichever
# matches your shell; both do the same thing).
#
# Verifies Node.js (major version at or above the floor pinned in .nvmrc) and npm
# are on PATH — npm drives everything (installs dependencies, runs build/lint/
# type/test via package.json scripts). Exits 0 when ready; if anything is missing
# it prints per-OS install commands and exits 1 — install it, then re-run.
#
# Usage: bash ./scripts/check-env.sh

set -euo pipefail
case "${1:-}" in -h|--help) sed -n '2,12p' "$0"; exit 0 ;; esac

repo_root="$(cd -- "$(dirname -- "$0")/.." && pwd)"
# First number in .nvmrc is the major floor — works for "24", "v24.1.0", "24.1".
floor="$(grep -oE '[0-9]+' "$repo_root/.nvmrc" 2>/dev/null | head -n1 || true)"
[ -n "$floor" ] || floor=24

problems=()
echo "==> Checking environment for TypeScript development"

# Required: Node.js at or above the .nvmrc floor (the runtime everything runs on).
if command -v node >/dev/null 2>&1; then
  major="$(node -p 'process.versions.node.split(".")[0]')"
  if [ "$major" -lt "$floor" ]; then
    problems+=("Node.js >= $floor (found $(node --version))")
  else
    echo "    node $(node --version)"
  fi
else
  problems+=("Node.js >= $floor ('node' is not on PATH)")
fi

# Required: npm (build/test/lint/format driver; ships with Node.js).
if command -v npm >/dev/null 2>&1; then
  echo "    npm $(npm --version)"
else
  problems+=("npm ('npm' is not on PATH — it normally ships with Node.js)")
fi

# Soft: git drives init's author/email defaults and the VCS workflow, but is not
# required to build.
command -v git >/dev/null 2>&1 || \
  echo "    note: git is not on PATH — init falls back to placeholder author/email."

if [ ${#problems[@]} -eq 0 ]; then
  echo
  echo "Environment ready. Next: bash ./scripts/init.sh --project-name ..."
  exit 0
fi

echo
echo "Environment NOT ready. Missing:"
for p in "${problems[@]}"; do echo "  - $p"; done
echo
echo "Install Node.js (LTS, includes npm), then re-run this check:"
echo "  Windows : winget install --id=OpenJS.NodeJS.LTS -e"
echo "  macOS   : brew install node"
echo "  Linux   : your distro's nodejs package (e.g. apt-get install nodejs npm),"
echo "            or nvm: nvm install $floor && nvm use $floor"
echo "  (any OS) : see https://nodejs.org/en/download"
exit 1
