---
description: Work the Foundry/Draft agent queue and keep polling for new work when the queue empties. The "set it and forget it" variant of /draft:work — invoke once at the start of a session, walk away, come back to delivered stories.
disable-model-invocation: true
---

# Watch the Draft queue

Same as `/draft:work`, but instead of stopping when the queue is
empty, sleep and re-check until either new work arrives or the user
interrupts. Use this when the operator wants the agent to run
unattended for a stretch — they kick off a session, walk away, and
come back to delivered stories.

The `draft` MCP tools (`mcp__draft__*`) bundled with this plugin
drive everything below.

## Configuration

Same env as `/draft:work`:

- `DRAFT_API_KEY` (required) — the workspace agent API key. If a tool
  call reports it's unset, tell the user to export it and stop.
- `DRAFT_API_URL` (optional) — defaults to
  `https://draft.foundryworks.dev`.

## 1. Load the workflow instructions — first, every time

Call `mcp__draft__context`. It returns Draft's own authoritative
instructions for operating within a workspace (state machine, claim
mechanics, comment + transition flow, hand-off protocol, mention
format, etc.). **Those instructions are the source of truth** —
follow them. Fetch fresh each run rather than relying on memory.

## 2. Drain the queue

Call `mcp__draft__queue` and work each available item to completion
using the MCP tools, exactly as the context instructions describe:

- `mcp__draft__claim_story` — claim ownership.
- `mcp__draft__transition_story` with `action: "start"`.
- `mcp__draft__comment` — post a short plan comment.
- Do the implementation. Run the project's tests / build.
- `mcp__draft__add_link` — attach the PR or commit URL if the
  project has a connected repo.
- `mcp__draft__transition_story` with `action: "finish"`.

Repeat for each available item in priority order. The watch loop
runs the same per-story flow as `/draft:work` — only step 3 differs.

## 3. When the queue empties — poll, don't stop

Once `mcp__draft__queue` reports no available work:

1. Print one line: `Queue empty — watching for new work. Sleeping
   5 minutes before next check. Interrupt with Esc / Ctrl-C to
   stop.`
2. Run `sleep 300` via the Bash tool with a timeout of at least
   360000 (6 minutes — Bash's default 2-minute timeout would cut
   the sleep short). Use `run_in_background: false` so the loop
   advances when the sleep completes.
3. Call `mcp__draft__queue` again.
   - If there are stories, drop back to **step 2** and drain them.
   - If still empty, repeat the sleep + re-check. There is no
     hardcoded stopping condition — the user ends the watch by
     interrupting.

5 minutes is the default poll interval. If `$ARGUMENTS` is a number,
treat it as the interval in seconds and use that instead (clamped to
[60, 3600] so a typo can't trigger every 2 seconds or sleep for a
day).

## Guardrails

- The `mcp__draft__context` response is canonical. If anything in
  this file conflicts with it, the API wins.
- Never transition a story to `accepted` — that's the human
  reviewer's call. `finish` is the right terminal state for agent
  work.
- If a particular story turns out far larger than expected or needs
  a decision you can't make, follow the context instructions for
  *blocking* (`transition_story` with `action: "block"`, plus a
  comment). Don't silently skip it — block it so a human sees it.
- The watch loop is intended for hands-off polling between known-
  scoped stories. If a story looks like it needs an architecture
  conversation, block it and let the user decide whether to take
  the watch off the queue while they answer.
- The MCP tools are the intended interface. The same operations are
  reachable as plain REST calls against `DRAFT_API_URL` with an
  `Authorization: Bearer $DRAFT_API_KEY` header, but prefer the
  tools.
