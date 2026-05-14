# Draft — Claude Code plugin

Connects a [Claude Code](https://claude.com/claude-code) session to a
[Foundry/Draft](https://draft.foundryworks.dev) workspace so an agent
can see the work queue and pick up tickets.

## What it does

- **On session start** — if `DRAFT_API_KEY` is set in the environment,
  the plugin quietly notes that Draft is connected and lists the
  available commands. Sessions without the key see nothing; the plugin
  is inert.
- **`/draft:queue`** — show the stories waiting in your agent queue
  (read-only).
- **`/draft:work`** — work the queue: claim the top story, implement
  it, and finish it, following the workflow instructions Draft serves
  over its API.
- **`mcp__draft__*` tools** — a bundled MCP server exposes the Draft
  API as typed tools (`queue`, `context`, `claim_story`,
  `transition_story`, `comment`, …). The commands above drive the
  loop through these tools.

The plugin does **not** hardcode how Draft works. It fetches the
workflow (`mcp__draft__context` → `GET /v1/agent/context`) from your
workspace at run time, so the protocol can evolve server-side without
a plugin update.

## Install

For local development, point Claude Code at the plugin directory:

```bash
claude --plugin-dir /path/to/draft-cc-plugin
```

After editing plugin files mid-session, reload with `/reload-plugins`.

**Requirement:** the MCP server is a Node script — Node 18+ must be on
`PATH` (it uses the built-in `fetch`). There are **no npm
dependencies** and no build step; the server runs straight from
source.

## Configure

Set these in your environment — your shell profile, or a project
`.env` you source. **Never commit the API key.**

| Variable        | Required | Default                          | Purpose                                     |
| --------------- | -------- | -------------------------------- | ------------------------------------------- |
| `DRAFT_API_KEY` | yes      | —                                | Your workspace agent API key (`fdrk_…`).    |
| `DRAFT_API_URL` | no       | `https://draft.foundryworks.dev` | Override for a self-hosted Draft instance.  |

Get an API key from your Draft workspace under **Settings → Agents**.
Both the session-start hook and the MCP server read the same two
variables.

## MCP tools

The bundled `draft` MCP server (`mcp/draft-mcp.js`) exposes:

| Tool                | What it does                                                    |
| ------------------- | --------------------------------------------------------------- |
| `whoami`            | The authenticated agent's identity.                             |
| `context`           | Draft's authoritative how-to-operate instructions.              |
| `queue`             | The agent work queue across all reachable projects.             |
| `get_story`         | One story by project id + number.                              |
| `list_comments`     | A story's comment thread.                                       |
| `story_activity`    | A story's activity timeline.                                    |
| `claim_story`       | Claim ownership (resolves your own user id).                    |
| `transition_story`  | Move a story through its state machine (start/finish/block/…).  |
| `comment`           | Post a comment on a story.                                      |
| `add_link`          | Attach a PR/commit URL to a story.                              |
| `create_story`      | File a new story (lands in the backlog for triage).             |
| `update_story`      | Patch arbitrary story fields (points, labels, …).               |

The server is dependency-free: it implements the MCP stdio transport
directly and uses Node's global `fetch`. One upside of going through
the server instead of raw `curl` — Node's resolver handles DNS, so
there's no `--resolve` fiddling when records are in flux.

## Layout

```
.claude-plugin/plugin.json   plugin manifest (declares the MCP server)
hooks/hooks.json             SessionStart hook wiring
scripts/session-init.sh      the hook script (silent unless DRAFT_API_KEY is set)
mcp/draft-mcp.js             zero-dependency MCP server wrapping the Draft API
skills/queue/SKILL.md        /draft:queue  — read-only queue view
skills/work/SKILL.md         /draft:work   — the ticket-working loop
```

## License

MIT — see [LICENSE](LICENSE).
