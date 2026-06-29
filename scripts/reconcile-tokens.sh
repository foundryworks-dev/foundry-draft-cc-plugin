#!/usr/bin/env bash
# Stop hook for the Foundry/Draft plugin (#257).
#
# Launches the token-spend reconciler detached so it never adds latency to a
# turn and never blocks the session. The reconciler backfills agent_tokens_used
# on the agent's finished stories that recorded 0 tokens because their
# claim/finish didn't go through the MCP tools (pure-REST agent, or the MCP
# server dropped mid-session). It self-dedupes rapid runs and is fully
# best-effort.
#
# Stays completely silent unless DRAFT_API_KEY is set — zero noise in sessions
# whose repo isn't connected to a Draft workspace.
set -uo pipefail

if [ -z "${DRAFT_API_KEY:-}" ]; then
  exit 0
fi

if ! command -v node >/dev/null 2>&1; then
  exit 0
fi

# Detach: the reconciler runs in the background and this hook returns
# immediately, so the turn isn't delayed by its API calls.
nohup node "${CLAUDE_PLUGIN_ROOT}/mcp/reconcile-tokens.js" >/dev/null 2>&1 &

exit 0
