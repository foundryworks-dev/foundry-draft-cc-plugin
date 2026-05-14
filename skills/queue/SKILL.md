---
description: Show the Foundry/Draft agent queue — a read-only snapshot of the stories waiting to be worked, without claiming or modifying anything.
---

# Show the Draft queue

Read-only. Does not claim, start, or modify any story.

## Configuration

- `DRAFT_API_KEY` (required) — read from the environment. If it is
  unset, tell the user to export it and stop.
- `DRAFT_API_URL` (optional) — defaults to
  `https://draft.foundryworks.dev`.

## Steps

1. `GET {DRAFT_API_URL}/v1/agent/queue` with
   `Authorization: Bearer $DRAFT_API_KEY`.
2. Summarize the stories that still need work (i.e. not yet finished
   or accepted): story number, type, state, points, and title — in the
   queue's priority order.
3. Stop there. To actually pick something up, the user runs
   `/draft:work`.
