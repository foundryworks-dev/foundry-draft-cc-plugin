---
description: Show the Foundry/Draft agent queue — a read-only snapshot of the stories waiting to be worked, without claiming or modifying anything.
---

# Show the Draft queue

Read-only. Does not claim, start, or modify any story.

## Steps

1. Call `mcp__draft__queue` — the `draft` MCP tool bundled with this
   plugin. It reads `DRAFT_API_KEY` / `DRAFT_API_URL` from the
   environment. If the key is unset, resolve it from the registry:
   `node "${CLAUDE_PLUGIN_ROOT}/scripts/foundry-registry.js" resolve`
   prints `DRAFT_API_KEY<TAB>DRAFT_API_URL` (the env value if set,
   otherwise a lease claimed via `/draft:agents`) — use that over REST.
   If it exits non-zero, tell the user to run `/draft:agents` or export
   `DRAFT_API_KEY`, and stop.
2. Summarize the stories that still need work (i.e. not yet finished
   or accepted): story number, type, state, points, and title — in the
   queue's priority order.
3. Stop there. To actually pick something up, the user runs
   `/draft:work`.
