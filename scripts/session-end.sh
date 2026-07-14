#!/usr/bin/env bash
# SessionEnd hook for the Foundry/Draft plugin (#194).
#
# Releases any agent key this session claimed from the local registry daemon,
# so it frees up promptly for the next agent instead of waiting out the server's
# idle auto-release. Fully best-effort and silent:
#   - Does nothing if no key was claimed (no active-lease.json).
#   - Does nothing if node is unavailable.
#   - The daemon/server idle auto-release is the backstop if this doesn't run.
set -uo pipefail

FOUNDRY_ROOT="${FOUNDRY_HOME:-$HOME/.foundry}"
if [ ! -f "$FOUNDRY_ROOT/active-lease.json" ]; then
  exit 0
fi
if ! command -v node >/dev/null 2>&1; then
  exit 0
fi

node "${CLAUDE_PLUGIN_ROOT}/scripts/foundry-registry.js" release >/dev/null 2>&1 || true
exit 0
