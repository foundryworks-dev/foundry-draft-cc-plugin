---
description: Work the Foundry/Draft agent queue — fetch the workflow context, claim the top story, implement it, and finish it. Invoke when the user wants to start working Draft tickets.
disable-model-invocation: true
---

# Work the Draft queue

Run the Foundry/Draft agent loop for this session.

## Configuration

- `DRAFT_API_KEY` (required) — the workspace API key, read from the
  environment. If it is unset, tell the user to export it and stop.
- `DRAFT_API_URL` (optional) — defaults to
  `https://draft.foundryworks.dev`.

Every API request sends `Authorization: Bearer $DRAFT_API_KEY`.

## 1. Load the workflow instructions — first, every time

`GET {DRAFT_API_URL}/v1/agent/context`

This returns Draft's own authoritative instructions for operating
within a workspace: the board model, the story state machine, how to
claim / start / comment / transition / finish a story, and any
workspace- or project-specific notes. **Those instructions are the
source of truth.** Follow them. Do not rely on memory or assumptions
about the Draft workflow — fetch this fresh each run, because it can
change server-side without a plugin update.

## 2. Work the queue

`GET {DRAFT_API_URL}/v1/agent/queue`

Pick up work and drive it to completion exactly as the context
instructions describe — typically: take the highest-priority item,
claim ownership, transition it to started, post a short plan comment,
do the implementation, run the project's tests / build, commit and
push if the project has a connected repo, then transition to finished.

If `$ARGUMENTS` names a specific story number, pick that story up
instead of the top of the queue.

## 3. Repeat or stop

When the queue has no more available work, say so and stop. Otherwise
continue to the next item — but check in with the user rather than
looping indefinitely if a story turns out far larger than expected or
needs a decision you can't make.

## Guardrails

- The `/v1/agent/context` response is canonical. If anything in this
  file conflicts with it, the API wins.
- Don't transition a story to `accepted` — that's the reviewer's call.
- If you genuinely can't proceed (a question only a human can answer),
  follow the context instructions for blocking the story rather than
  abandoning it.
