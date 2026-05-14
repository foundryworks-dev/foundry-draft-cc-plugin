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
- \`/draft:work\`  — start working tickets from the queue.

Do not start working tickets unprompted — wait for the user to invoke
\`/draft:work\` or ask for it. The authoritative instructions for
operating within Draft are served by the API and fetched by those
commands; they are not duplicated here.
EOF
