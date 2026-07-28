---
description: Show the Foundry/Draft agent queue — a read-only snapshot of the stories waiting to be worked, without claiming or modifying anything.
---

# Show the Draft queue

Read-only. Does not claim, start, or modify any story.

## Steps

1. Call `mcp__foundry__queue` — the `foundry` MCP tool bundled with this
   plugin. It reads `FOUNDRY_API_KEY` / `FOUNDRY_API_URL` from the
   environment. If the key is unset, resolve it from the registry:
   `node "${CLAUDE_PLUGIN_ROOT}/scripts/foundry-registry.js" resolve`
   prints `FOUNDRY_API_KEY<TAB>FOUNDRY_API_URL` (the env value if set,
   otherwise a lease claimed via `/foundry:agents`) — use that over REST.
   If it exits non-zero, tell the user to run `/foundry:agents` or export
   `FOUNDRY_API_KEY`, and stop.
2. Summarize the stories that still need work (i.e. not yet finished
   or accepted): story number, type, state, points, and title — in the
   queue's priority order.
3. Stop there. To actually pick something up, the user runs
   `/foundry:work`.
