#!/usr/bin/env node
// Token-spend reconciler — the safety net for #257.
//
// Per-story token recording normally happens inside the MCP server: it
// snapshots cumulative tokens on claim_story and PATCHes the delta on the
// finish transition (#135). But any story whose claim/finish does NOT go
// through those tools — a pure-REST agent, or a session whose MCP server
// dropped and fell back to `curl` — records 0 tokens, and people rely on
// the metric to gauge story complexity.
//
// This script closes that gap. The Stop hook launches it (detached) after
// each turn; it finds the agent's finished/delivered stories that still
// have a null agent_tokens_used, attributes tokens by time-windowing THIS
// session's transcript over each story's started→finished interval (same
// input+output+cache definition the plugin uses), and PATCHes them.
//
// It is independent of whether claim/finish went through MCP or REST, so it
// catches the gap either way. Entirely best-effort: every failure is logged
// to stderr and nothing here can block or break a session. It only attributes
// work visible in the current session's transcript — a story whose tokens are
// 0 in this window (e.g. finished in an earlier session) is left untouched.

const fs = require("fs");
const os = require("os");
const path = require("path");

const API_URL = (
  process.env.DRAFT_API_URL || "https://draft.foundryworks.dev"
).replace(/\/+$/, "");
const API_KEY = process.env.DRAFT_API_KEY || "";
const SESSION_ID = process.env.CLAUDE_CODE_SESSION_ID || "";
const STATE_DIR = path.join(os.homedir(), ".claude", "foundry-draft-plugin");
// Dedupe overlapping runs from rapid turns: skip if a run started within this
// window. Short enough that a story finished in the final turn is still picked
// up on that turn's run.
const DEDUPE_MS = 10 * 1000;

function log(m) {
  process.stderr.write("draft-reconcile: " + m + "\n");
}

// Silent no-op outside a Draft-connected Claude Code session.
if (!API_KEY || !SESSION_ID) process.exit(0);

const lockFile = path.join(STATE_DIR, "reconcile.json");
try {
  const last = JSON.parse(fs.readFileSync(lockFile, "utf8")).last || 0;
  if (Date.now() - last < DEDUPE_MS) process.exit(0);
} catch {
  /* no prior run */
}
try {
  fs.mkdirSync(STATE_DIR, { recursive: true });
  fs.writeFileSync(lockFile, JSON.stringify({ last: Date.now() }));
} catch {
  /* best-effort */
}

// Resolve this session's transcript: <session-id>.jsonl under any
// ~/.claude/projects/<encoded-cwd>/ dir (covers cwd / git-worktree mismatch).
function findTranscript(id) {
  const base = path.join(os.homedir(), ".claude", "projects");
  let dirs;
  try {
    dirs = fs.readdirSync(base);
  } catch {
    return null;
  }
  for (const d of dirs) {
    const p = path.join(base, d, id + ".jsonl");
    try {
      if (fs.statSync(p).isFile()) return p;
    } catch {
      /* keep looking */
    }
  }
  return null;
}

// Sum token usage across transcript rows whose timestamp falls in [startMs,
// endMs]. Returns null if the transcript can't be read.
function sumUsageBetween(transcriptPath, startMs, endMs) {
  let data;
  try {
    data = fs.readFileSync(transcriptPath, "utf8");
  } catch {
    return null;
  }
  const a = { input: 0, output: 0, cache_read: 0, cache_creation: 0 };
  for (const line of data.split("\n")) {
    if (!line.trim()) continue;
    let row;
    try {
      row = JSON.parse(line);
    } catch {
      continue;
    }
    const u = row && row.message && row.message.usage;
    const ts = row && row.timestamp;
    if (!u || !ts) continue;
    const t = Date.parse(ts);
    if (isNaN(t) || t < startMs || t > endMs) continue;
    a.input += u.input_tokens || 0;
    a.output += u.output_tokens || 0;
    a.cache_read += u.cache_read_input_tokens || 0;
    a.cache_creation += u.cache_creation_input_tokens || 0;
  }
  a.total = a.input + a.output + a.cache_read + a.cache_creation;
  return a;
}

async function api(method, p, body) {
  const res = await fetch(API_URL + p, {
    method,
    headers: {
      Authorization: "Bearer " + API_KEY,
      "Content-Type": "application/json",
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!res.ok) throw new Error(method + " " + p + " -> " + res.status);
  if (res.status === 204) return null;
  return res.json();
}

(async () => {
  const transcript = findTranscript(SESSION_ID);
  if (!transcript) process.exit(0);

  let meId;
  let projects;
  try {
    meId = (await api("GET", "/v1/auth/me")).user.id;
    const pj = await api("GET", "/v1/projects");
    projects = Array.isArray(pj) ? pj : pj.projects || [];
  } catch (e) {
    log("setup: " + (e && e.message));
    process.exit(0);
  }

  for (const proj of projects) {
    let stories;
    try {
      const sj = await api("GET", `/v1/projects/${proj.id}/stories`);
      stories = Array.isArray(sj) ? sj : sj.stories || [];
    } catch {
      continue;
    }
    for (const s of stories) {
      if (s.owner_id !== meId) continue;
      if (s.state !== "finished" && s.state !== "delivered") continue;
      if (s.agent_tokens_used != null) continue;

      let events;
      try {
        const aj = await api(
          "GET",
          `/v1/projects/${proj.id}/stories/${s.number}/activity`,
        );
        events = aj.events || [];
      } catch {
        continue;
      }
      const startedAt = events
        .filter((e) => e.action === "started")
        .map((e) => e.created_at)
        .sort()[0];
      const finishedAt = events
        .filter((e) => e.action === "finished")
        .map((e) => e.created_at)
        .sort()
        .slice(-1)[0];
      if (!startedAt || !finishedAt) continue;

      const tok = sumUsageBetween(
        transcript,
        Date.parse(startedAt),
        Date.parse(finishedAt),
      );
      // total <= 0 means none of this story's work is in this session's
      // transcript (e.g. it was finished in an earlier session) — leave it
      // for the session that actually did the work.
      if (!tok || tok.total <= 0) continue;

      try {
        await api("PATCH", `/v1/projects/${proj.id}/stories/${s.number}`, {
          agent_tokens_used: tok.total,
          agent_input_tokens: tok.input,
          agent_output_tokens: tok.output,
          agent_cache_read_tokens: tok.cache_read,
          agent_cache_creation_tokens: tok.cache_creation,
        });
        log(`backfilled #${s.number} in ${proj.id} = ${tok.total}`);
      } catch (e) {
        log(`patch #${s.number}: ${e && e.message}`);
      }
    }
  }
  process.exit(0);
})().catch((e) => {
  log("fatal: " + (e && e.message));
  process.exit(0);
});
