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

The plugin does **not** hardcode how Draft works. It fetches the
workflow (`GET /v1/agent/context`) from your workspace at run time, so
the protocol can evolve server-side without a plugin update. The
plugin is just the connective tissue: a session-start hook and two
thin commands.

## Install

For local development, point Claude Code at the plugin directory:

```bash
claude --plugin-dir /path/to/draft-cc-plugin
```

After editing plugin files mid-session, reload with `/reload-plugins`.

## Configure

Set these in your environment — your shell profile, or a project
`.env` you source. **Never commit the API key.**

| Variable        | Required | Default                          | Purpose                                            |
| --------------- | -------- | -------------------------------- | -------------------------------------------------- |
| `DRAFT_API_KEY` | yes      | —                                | Your workspace agent API key (`fdrk_…`).           |
| `DRAFT_API_URL` | no       | `https://draft.foundryworks.dev` | Override for a self-hosted Draft instance.         |

Get an API key from your Draft workspace under **Settings → Agents**.

## Layout

```
.claude-plugin/plugin.json   plugin manifest
hooks/hooks.json             SessionStart hook wiring
scripts/session-init.sh      the hook script (silent unless DRAFT_API_KEY is set)
skills/queue/SKILL.md        /draft:queue  — read-only queue view
skills/work/SKILL.md         /draft:work   — the ticket-working loop
```

## License

TODO — pick a license before publishing.
