---
description: Re-fetch Foundry/Draft's authoritative operating instructions (the workspace context) from the API and adopt them as canonical for the rest of the session. Use when the workflow rules may have changed server-side, or when you want to re-ground a long-running session.
---

# Refresh the Draft workflow context

Force a fresh pull of Draft's authoritative operating instructions from
the API, using the `draft` MCP tools (`mcp__draft__*`) bundled with this
plugin. The instructions live server-side and **can change**, so this is
how you re-ground a session on the latest rules without restarting it.

This is read-only. It claims, starts, and modifies nothing — it only
re-loads the context.

## Configuration

The MCP server reads its config from the environment:

- `DRAFT_API_KEY` (required) — the workspace agent API key. If a tool
  call reports it's unset, tell the user to export it and stop.
- `DRAFT_API_URL` (optional) — defaults to
  `https://draft.foundryworks.dev`.

## Steps

1. Call `mcp__draft__context`. It re-fetches Draft's own authoritative
   instructions for operating within the workspace (the board model,
   the story state machine, claim/start/comment/transition/finish
   mechanics, the @-mention format, hand-off protocol, and any
   workspace- or project-specific notes) straight from the API.
2. **Adopt the freshly returned text as canonical**, replacing any
   earlier understanding from this session — including anything cached
   from a previous `/draft:work`, `/draft:watch`, or `/draft:refresh`
   call. If the new context conflicts with what you were doing, the new
   context wins.
3. Briefly tell the user what (if anything) changed since you last
   loaded it — e.g. new workspace instructions, a changed transition
   rule, an updated role description — or confirm it's unchanged.

## Notes

- This does **not** start or continue working the queue. To do that,
  run `/draft:work` (which loads the context itself before working) or
  `/draft:watch`.
- The `mcp__draft__context` response is always canonical: if anything in
  the plugin's skill files conflicts with it, the API wins.
