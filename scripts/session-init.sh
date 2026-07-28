#!/usr/bin/env bash
# SessionStart hook for the Foundry/Draft plugin.
#
# Stays completely silent unless a workspace key is set in the
# environment — so it adds zero noise to sessions whose repo isn't
# connected to a Draft workspace. When the key IS present, it injects
# a short notice that the /foundry commands are available.
#
# FOUNDRY_API_KEY / FOUNDRY_API_URL are the current names; the DRAFT_*
# ones are still honored and are not going away (#456).
#
# It deliberately does NOT fetch the queue or the workflow
# instructions here. That work belongs in the /foundry:queue and
# /foundry:work skills, where Claude has full tool access and can parse
# the API responses. Keeping this script trivial also keeps it
# portable — no jq / python dependency.
set -uo pipefail

API_KEY="${FOUNDRY_API_KEY:-${DRAFT_API_KEY:-}}"

if [ -z "$API_KEY" ]; then
  # No explicit key. If the Foundry Agent Registry daemon is running, the
  # operator can pick + claim an agent key from it instead (#194) — advertise
  # that path. Otherwise stay completely silent (repo isn't Draft-connected).
  FOUNDRY_ROOT="${FOUNDRY_HOME:-$HOME/.foundry}"
  if [ -f "$FOUNDRY_ROOT/daemon.json" ]; then
    cat <<EOF
A Foundry Agent Registry daemon is running, but no FOUNDRY_API_KEY is set.

- \`/foundry:agents\` — pick an agent key from the registry and claim it for
  this session. Then use \`/foundry:queue\` / \`/foundry:work\` / \`/foundry:watch\`
  as that agent.

(If you'd rather key the session directly, export FOUNDRY_API_KEY and the
registry step is skipped entirely. The legacy DRAFT_API_KEY also works.)
EOF
  fi
  exit 0
fi

API_URL="${FOUNDRY_API_URL:-${DRAFT_API_URL:-https://app.foundryworks.dev}}"

cat <<EOF
A Foundry/Draft connection is available in this session (a workspace
API key is set; workspace API: ${API_URL}).

- \`/foundry:queue\` — show what work is waiting (read-only).
- \`/foundry:work\`  — drain the queue once, then stop.
- \`/foundry:watch\` — drain the queue, then poll for new work in a
  loop (default 5-minute interval). Use this when the operator
  wants to walk away and come back to delivered stories.
- \`/foundry:refresh\` — re-fetch the workspace's authoritative
  operating instructions from the API and adopt them as canonical
  (read-only). Use when the workflow rules may have changed.

Do not start working tickets unprompted — wait for the user to invoke
one of those commands or ask for it. The authoritative instructions
for operating within Draft are served by the API and fetched by
those commands; they are not duplicated here.
EOF
