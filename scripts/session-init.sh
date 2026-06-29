#!/usr/bin/env bash
# SessionStart hook for the Foundry/Draft plugin.
#
# Stays completely silent unless DRAFT_API_KEY is set in the
# environment — so it adds zero noise to sessions whose repo isn't
# connected to a Draft workspace. When the key IS present, it injects
# a short notice that the /draft commands are available.
#
# It deliberately does NOT fetch the queue or the workflow
# instructions here. That work belongs in the /draft:queue and
# /draft:work skills, where Claude has full tool access and can parse
# the API responses. Keeping this script trivial also keeps it
# portable — no jq / python dependency.
set -uo pipefail

if [ -z "${DRAFT_API_KEY:-}" ]; then
  # Not a Draft-connected session — say nothing at all.
  exit 0
fi

API_URL="${DRAFT_API_URL:-https://draft.foundryworks.dev}"

cat <<EOF
A Foundry/Draft connection is available in this session (DRAFT_API_KEY
is set; workspace API: ${API_URL}).

- \`/draft:queue\` — show what work is waiting (read-only).
- \`/draft:work\`  — drain the queue once, then stop.
- \`/draft:watch\` — drain the queue, then poll for new work in a
  loop (default 5-minute interval). Use this when the operator
  wants to walk away and come back to delivered stories.
- \`/draft:refresh\` — re-fetch the workspace's authoritative
  operating instructions from the API and adopt them as canonical
  (read-only). Use when the workflow rules may have changed.

Do not start working tickets unprompted — wait for the user to invoke
one of those commands or ask for it. The authoritative instructions
for operating within Draft are served by the API and fetched by
those commands; they are not duplicated here.
EOF
