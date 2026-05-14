---
description: Work the Foundry/Draft agent queue — fetch the workflow context, claim the top story, implement it, and finish it. Invoke when the user wants to start working Draft tickets.
disable-model-invocation: true
---

# Work the Draft queue

Run the Foundry/Draft agent loop for this session, using the `draft`
MCP tools (`mcp__draft__*`) bundled with this plugin.

## Configuration

The MCP server reads its config from the environment:

- `DRAFT_API_KEY` (required) — the workspace agent API key. If a tool
  call reports it's unset, tell the user to export it and stop.
- `DRAFT_API_URL` (optional) — defaults to
  `https://draft.foundryworks.dev`.

## 1. Load the workflow instructions — first, every time

Call `mcp__draft__context`. It returns Draft's own authoritative
instructions for operating within a workspace: the board model, the
story state machine, claim/start/comment/transition/finish mechanics,
and any workspace- or project-specific notes. **Those instructions
are the source of truth** — follow them. They can change server-side,
so fetch them fresh each run rather than relying on memory.

## 2. Work the queue

Call `mcp__draft__queue` and take the highest-priority item (the
context explains the ordering). Then drive it to completion with the
matching tools, exactly as the context instructions describe:

- `mcp__draft__claim_story` — claim ownership (resolves your own user
  id for you).
- `mcp__draft__transition_story` with `action: "start"`.
- `mcp__draft__comment` — post a short plan comment.
- Do the implementation. Run the project's tests / build.
- `mcp__draft__add_link` — attach the PR or commit URL if the project
  has a connected repo.
- `mcp__draft__transition_story` with `action: "finish"`.

`mcp__draft__get_story`, `mcp__draft__list_comments`, and
`mcp__draft__story_activity` are there for reading detail along the
way — e.g. check for reviewer replies before you finish.

If `$ARGUMENTS` names a specific story number, pick that up instead of
the top of the queue.

## 3. Repeat or stop

When `mcp__draft__queue` shows no available work, say so and stop.
Otherwise continue to the next item — but check in with the user
rather than looping indefinitely if a story turns out far larger than
expected or needs a decision you can't make.

## Guardrails

- The `mcp__draft__context` response is canonical. If anything in this
  file conflicts with it, the API wins.
- Never transition a story to `accepted` — that's the human reviewer's
  call. `finish` is the right terminal state for agent work.
- If you genuinely can't proceed (a question only a human can
  answer), follow the context instructions for *blocking* the story
  (`transition_story` with `action: "block"`, plus a comment
  explaining what you need) rather than abandoning it.
- The MCP tools are the intended interface. If they're somehow
  unavailable in the session, the same operations are plain REST
  calls against `DRAFT_API_URL` with an
  `Authorization: Bearer $DRAFT_API_KEY` header — but prefer the tools.
