---
description: Pick and claim an agent key from the local Foundry Agent Registry daemon, instead of being handed a DRAFT_API_KEY by hand. Lists the agents/keys you may lease grouped by project, you choose one, and the plugin claims it for this session.
---

# Pick an agent from the registry

Use this when `DRAFT_API_KEY` is **not** already set and you're running the
Foundry Agent Registry daemon (`foundry daemon`). It lets the operator pick
which agent identity this session should work as, and claims that key through
the daemon — no key is pasted by hand.

If `DRAFT_API_KEY` **is** already set in the environment, the registry flow is
unnecessary: this session is already keyed, and `/draft:work` / `/draft:watch`
work directly. Say so and stop.

The broker client is `${CLAUDE_PLUGIN_ROOT}/scripts/foundry-registry.js` (Node);
it talks only to the local daemon over loopback and never handles an operator
token. All steps below go through it.

## 1. Confirm the daemon is running

Run:

```
node "${CLAUDE_PLUGIN_ROOT}/scripts/foundry-registry.js" status
```

- Exit code 3 → the daemon isn't running. Tell the operator to start it with
  `foundry daemon &` (and `foundry login` if they haven't authenticated), then
  stop. Do not fall back to anything.
- Success → it prints the environments, which are logged in, and any leases the
  daemon is already holding. Note the active environment and whether `prod` is
  in play.

## 2. List the leasable keys

```
node "${CLAUDE_PLUGIN_ROOT}/scripts/foundry-registry.js" keys
```

This prints a table of the keys with a **Cross-Project** column (a ✓ means the
agent is registered at the workspace level and works across every project) and
a **Project** column (the team name when the agent is scoped to one project),
plus availability (**available** / **in use**, with who holds it), env, and a
`[PROD]` flag. Present this to the operator clearly and ask which agent they
want to work as. Only `available` keys can be claimed — if they pick one that's
in use, say so and re-ask. Be extra explicit when a choice is `[PROD]`.

## 3. Claim the chosen key

With the `key_id` (and its `env`) from the operator's choice:

```
node "${CLAUDE_PLUGIN_ROOT}/scripts/foundry-registry.js" claim <key_id> \
  --env <env> --plugin draft-cc --repo "<owner/repo if known>" \
  --session-id "${CLAUDE_CODE_SESSION_ID:-}"
```

- Exit 0 → the key is claimed. The daemon returns the lease token (used as this
  session's `DRAFT_API_KEY`) and the API base URL; the broker records them in
  `~/.foundry/active-lease.json` (honoring `$FOUNDRY_HOME`) for the rest of the
  session, and auto-heartbeats the lease. Tell the operator which agent + env
  they're now working as.
- A "already in use" error → the key was claimed by someone else in the
  meantime. Go back to step 2 and pick another.

## 4. Proceed with the normal flow

Once claimed, `/draft:queue`, `/draft:work`, and `/draft:watch` operate as the
claimed agent: they resolve the credential with

```
node "${CLAUDE_PLUGIN_ROOT}/scripts/foundry-registry.js" resolve
```

which prints `DRAFT_API_KEY<TAB>DRAFT_API_URL` — the environment's
`DRAFT_API_KEY` if set (backward compatible), otherwise the claimed lease. Use
that credential for the Draft REST calls.

## Lifecycle notes

- **Release on exit** happens automatically via the plugin's SessionEnd hook
  (it calls `foundry-registry.js release`). If the session dies without
  releasing, the daemon/server idle auto-release reclaims the key after its TTL.
- **Budget / kill-switch:** when a turn reports usage through the daemon
  (`foundry-registry.js usage '{…}'`), a `should_stop: true` response (broker
  exit code 10) means the key's budget is spent — stop taking new work and tell
  the operator.
- **Never** paste or echo the lease token into the transcript; treat it like any
  other credential.
