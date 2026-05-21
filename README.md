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
  over its API. Stops when the queue empties.
- **`/draft:watch`** — same as `/draft:work`, but instead of stopping
  when the queue empties it sleeps (default 5 min) and re-checks
  until new work arrives or you interrupt. Set-and-forget — invoke
  once, walk away, come back to delivered stories. Pass an argument
  to override the interval, e.g. `/draft:watch 60`.
- **`mcp__draft__*` tools** — a bundled MCP server exposes the Draft
  API as typed tools (`queue`, `context`, `claim_story`,
  `transition_story`, `comment`, …). The commands above drive the
  loop through these tools.

The plugin does **not** hardcode how Draft works. It fetches the
workflow (`mcp__draft__context` → `GET /v1/agent/context`) from your
workspace at run time, so the protocol can evolve server-side without
a plugin update.

## Install

This repo is its own Claude Code marketplace. Add it once, then
install the plugin from it:

```
/plugin marketplace add foundryworks-dev/foundry-draft-cc-plugin
/plugin install draft@foundry-plugins
```

To update later, after a new version is published:

```
/plugin update draft@foundry-plugins
```

**Requirement:** the MCP server is a Node script — Node 18+ must be on
`PATH` (it uses the built-in `fetch`). There are **no npm
dependencies** and no build step; the server runs straight from
source.

### Local development

To hack on the plugin itself, point Claude Code at the working copy
instead of installing from the marketplace:

```bash
claude --plugin-dir /path/to/draft-cc-plugin
```

After editing plugin files mid-session, reload with `/reload-plugins`.

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

## Permissions

The first time Claude Code calls one of the `mcp__draft__*` tools
it asks you to approve it. To make the prompts go away:

- **One-click** — when Claude Code prompts, choose **Always allow**.
  It persists the rule to your `~/.claude/settings.json` and future
  calls go through silently.
- **Pre-set** — paste this into `~/.claude/settings.json` before the
  first call:

  ```json
  {
    "permissions": {
      "allow": ["mcp__draft__*"]
    }
  }
  ```

The plugin can't ship this allowlist itself: Claude Code
deliberately separates plugin trust (installation) from tool-call
policy (permissions), and plugin-bundled `settings.json` doesn't
accept a `permissions` block. The plugin gives you the MCP server;
allowing it to fire without asking each time is a one-time choice
you make.

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
skills/work/SKILL.md         /draft:work   — drain the queue once
skills/watch/SKILL.md        /draft:watch  — drain + poll for new work
```

## License

MIT — see [LICENSE](LICENSE).
