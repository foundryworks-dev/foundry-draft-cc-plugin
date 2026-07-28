# Draft — Claude Code plugin

Connects a [Claude Code](https://claude.com/claude-code) session to a
[Foundry/Draft](https://app.foundryworks.dev) workspace so an agent
can see the work queue and pick up tickets.

## What it does

- **On session start** — if `FOUNDRY_API_KEY` is set in the environment,
  the plugin quietly notes that Draft is connected and lists the
  available commands. Sessions without the key see nothing; the plugin
  is inert.
- **`/foundry:queue`** — show the stories waiting in your agent queue
  (read-only).
- **`/foundry:work`** — work the queue: claim the top story, implement
  it, and finish it, following the workflow instructions Draft serves
  over its API. Stops when the queue empties.
- **`/foundry:watch`** — same as `/foundry:work`, but instead of stopping
  when the queue empties it sleeps (default 5 min) and re-checks
  until new work arrives or you interrupt. Set-and-forget — invoke
  once, walk away, come back to delivered stories. Pass an argument
  to override the interval, e.g. `/foundry:watch 60`.
- **`/foundry:refresh`** — re-fetch Draft's authoritative operating
  instructions (the workspace context) from the API and adopt them as
  canonical for the rest of the session (read-only). Handy for a
  long-running session when the workflow rules may have changed
  server-side.
- **`/foundry:agents`** — pick an agent key from the **Foundry Agent
  Registry** instead of exporting one by hand. When the local `foundry
  daemon` is running and `FOUNDRY_API_KEY` is unset, this lists the keys
  you may lease in a table — a Cross-Project column (workspace-level
  agents) and a Project column (project-scoped agents), plus
  availability — you choose one, and the plugin claims it for the
  session. The other commands then operate as that agent. If
  `FOUNDRY_API_KEY` is already set, the registry flow is skipped entirely
  and the plugin behaves exactly as before. See "Agent Key Registry"
  below.
- **`mcp__foundry__*` tools** — a bundled MCP server exposes the Draft
  API as typed tools (`queue`, `context`, `claim_story`,
  `transition_story`, `comment`, …). The commands above drive the
  loop through these tools.

The plugin does **not** hardcode how Draft works. It fetches the
workflow (`mcp__foundry__context` → `GET /v1/agent/context`) from your
workspace at run time, so the protocol can evolve server-side without
a plugin update.

## Install

This repo is its own Claude Code marketplace. Add it once, then
install the plugin from it:

```
/plugin marketplace add foundryworks-dev/foundry-draft-cc-plugin
/plugin install foundry@foundry-plugins
```

To update later, after a new version is published:

```
/plugin update foundry@foundry-plugins
```

### Upgrading from `draft@foundry-plugins`

The plugin was named `draft` before 0.9.0, which is where the old
`/draft:queue` / `/draft:work` commands came from. It is now `foundry`,
and the commands are `/foundry:queue`, `/foundry:work`, and so on.

You do not need to do anything special. The marketplace carries a
`renames` entry, so Claude Code migrates an existing install for you:
it loads the plugin under the new name, prints a one-line
`Renamed to "foundry"` notice, and rewrites the old key in your
settings. Two cases need one manual step:

- Because this marketplace is a git source, Claude Code may report
  `plugin-cache-miss` after the rename. Run
  `/plugin install foundry@foundry-plugins` once to fetch it under the
  new name.
- Automatic migration needs Claude Code **v2.1.193 or later**. Older
  versions ignore `renames` and report `plugin-not-found` for `draft`;
  install under the new name once and you are current.

Only the *commands* moved. The `mcp__draft__*` tool namespace still
resolves (see [Tool names](#tool-names-foundry-and-draft)), as do
`DRAFT_API_KEY` / `DRAFT_API_URL` and the `draft.foundryworks.dev`
host.

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
| `FOUNDRY_API_KEY` | yes      | —                                | Your workspace agent API key (`fdrk_…`).    |
| `FOUNDRY_API_URL` | no       | `https://app.foundryworks.dev` | Override for a self-hosted Draft instance.  |

**The `DRAFT_API_KEY` / `DRAFT_API_URL` names are still accepted** and are
not going away. `FOUNDRY_*` wins when both are set; otherwise `DRAFT_*` is
used and the plugin prints a one-line notice on stderr. Existing setups need
no change (#456).

Get an API key from your Draft workspace under **Settings → Agents**.

### Tool names: `foundry` and `draft`

The plugin registers the MCP server under **two keys**, so both tool
namespaces resolve to the same handler:

| Namespace | Status |
| --------- | ------ |
| `mcp__foundry__*` | the name to use going forward |
| `mcp__draft__*`   | still works; retired only once usage telemetry says nobody calls it (#458) |

The prefix comes from the **client-side config key**, not from anything the
server returns — `tools/list` hands back bare tool names like `queue`. So
aliasing a namespace means mounting the same script twice. The cost is that
every tool appears twice in a session's tool list; that is inherent to MCP
namespacing, not something the server can dedupe (#457).

Each registration passes its own `--server-key=` so the process knows which
namespace it is serving — without it the two are indistinguishable, since
`tools/list` returns bare names either way.

Both the session-start hook and the MCP server read the same two
variables.

### What gets reported about legacy names (#458)

`draft.` / `DRAFT_*` / `draft:` are supported indefinitely, so retiring any of
them has to be a decision backed by evidence rather than a guess. To make that
possible, requests carry an `X-Foundry-Legacy` header naming the legacy names
**this process is running on** — the `DRAFT_*` variables that supplied its
config, and `prefix=draft` when invoked under the legacy namespace. The server
logs those against your agent identity.

It is names only: no credential, no arguments, no story content, and nothing
at all is sent by a session already on `FOUNDRY_*` and `mcp__foundry__*`.

## Permissions

The first time Claude Code calls one of the `mcp__foundry__*` tools
it asks you to approve it. To make the prompts go away:

- **One-click** — when Claude Code prompts, choose **Always allow**.
  It persists the rule to your `~/.claude/settings.json` and future
  calls go through silently.
- **Pre-set** — paste this into `~/.claude/settings.json` before the
  first call:

  ```json
  {
    "permissions": {
      "allow": ["mcp__foundry__*"]
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

The bundled `foundry` MCP server (`mcp/draft-mcp.js`) exposes:

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
| `library_write`     | Create or update a Library wiki page by (project, slug).        |

The server is dependency-free: it implements the MCP stdio transport
directly and uses Node's global `fetch`. One upside of going through
the server instead of raw `curl` — Node's resolver handles DNS, so
there's no `--resolve` fiddling when records are in flux.

### Auto-tracked token spend per story

`claim_story` and `transition_story` quietly maintain a per-session
snapshot of the cumulative Anthropic token total (sum of
`input_tokens` + `output_tokens` + `cache_read_input_tokens` +
`cache_creation_input_tokens`) drawn straight from the Claude Code
session's transcript. On `transition_story` with `action: "finish"`
the diff since claim is PATCHed onto the story as `agent_tokens_used`
— the field Draft's story modal renders to show what each AI-
completed story actually cost. `restart` re-seeds the snapshot so
the next finish reports only post-restart spend; `block` / `unblock`
leave it alone so a story that finishes after a block-then-unblock
cycle still captures total spend since the original claim. Snapshots
live in `~/.claude/foundry-draft-plugin/<session-id>.json` and are
dropped on a successful finish. The whole path is best-effort and
silent: outside Claude Code (no transcript file findable) every
step short-circuits to a no-op, and a failed PATCH at finish is
logged to stderr but doesn't block the actual transition.

### Token-spend safety net (Stop hook)

The auto-tracking above only fires when `claim_story` / `transition_story`
mediate the work. If an agent drives Draft through the **REST API**
directly — a pure-REST client, or a session whose MCP server dropped and
fell back to `curl` — those tools never run and the story records 0
tokens. A `Stop` hook closes that gap: after each turn it launches
`scripts/reconcile-tokens.sh` (detached, so it never adds turn latency),
which finds the agent's finished/delivered stories that still have a null
`agent_tokens_used` and backfills them by time-windowing the current
session's transcript over each story's `started → finished` interval (the
same input + output + cache token definition used above). It only
attributes work visible in this session's transcript, self-dedupes rapid
runs, and is fully best-effort — silent and harmless when `FOUNDRY_API_KEY`
isn't set. (Codex and Hermes have no equivalent Stop-hook mechanism, so
this safety net is Claude-Code-specific for now.)

## Agent Key Registry (`/foundry:agents`)

Instead of exporting a `FOUNDRY_API_KEY` by hand, you can run the **Foundry
Agent Registry** daemon (`foundry daemon`, a separate resident local
process) and let it broker keys to your agents. It holds your Foundry login
and owns the server-side lease calls; the plugin only talks to its local
loopback IPC — it never sees an operator token.

Flow: with the daemon running and `FOUNDRY_API_KEY` **unset**, `/foundry:agents`
lists the keys you may lease (grouped by project, marked available / in use,
`[PROD]` flagged), you pick one, and the plugin claims it. The claim records
a session-local lease (`~/.foundry/active-lease.json`, honoring
`$FOUNDRY_HOME`); `/foundry:queue` / `/foundry:work` / `/foundry:watch` then resolve
the credential from that lease and operate as the claimed agent. The daemon
auto-heartbeats the lease; a `SessionEnd` hook releases it on exit (and the
server's idle auto-release is the backstop).

**Backward compatible:** if `FOUNDRY_API_KEY` is set in the environment, the
registry flow is skipped entirely — everything works exactly as before.

The broker client is `scripts/foundry-registry.js` (Node, zero-dependency),
which speaks the daemon's documented local IPC (`/keys`, `/claim`,
`/leases/{id}/{usage,release}`). See the Foundry Agent Registry repo for the
daemon itself.

## Layout

```
.claude-plugin/plugin.json   plugin manifest (declares the MCP server)
hooks/hooks.json             SessionStart + Stop + SessionEnd hook wiring
scripts/session-init.sh      SessionStart script (silent unless FOUNDRY_API_KEY or a daemon is present)
scripts/session-end.sh       SessionEnd hook — releases a claimed registry lease
scripts/reconcile-tokens.sh  Stop hook — launches the token-spend reconciler
scripts/foundry-registry.js  Agent Key Registry broker client (talks to the local daemon)
mcp/draft-mcp.js             zero-dependency MCP server wrapping the Draft API
skills/queue/SKILL.md        /foundry:queue   — read-only queue view
skills/work/SKILL.md         /foundry:work    — drain the queue once
skills/watch/SKILL.md        /foundry:watch   — drain + poll for new work
skills/refresh/SKILL.md      /foundry:refresh — re-pull the workflow context
skills/agents/SKILL.md       /foundry:agents  — pick + claim a key from the registry
```

## License

MIT — see [LICENSE](LICENSE).
