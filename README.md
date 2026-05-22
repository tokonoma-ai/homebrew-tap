# Tokonoma Homebrew Tap

Local-trial distribution for [tokonoma-mcp](https://github.com/tokonoma-ai/tokonoma-mcp), packaged for one-command Mac install.

## What is Tokonoma?

Tokonoma gives your coding agent (Claude Code, Cursor, Codex) the context to act like your team's expert SRE — memory of past investigations, RCAs, runbooks, your internal glossary and system map, cross-team issue history.

When your agent sees a familiar symptom, it doesn't start from scratch. It returns a short, attributed answer pointing to what worked last time, with a link to the ticket. It's like having your team's tech lead on call while you troubleshoot and code — less escalation, fewer war rooms, more self-unblocking.

**Local install. No telemetry. Nothing leaves your laptop.** Postgres and the memory store run entirely on your machine.

## What it's good for

- **Starting an investigation.** Your agent uses memory from you and your teammates to skip dead-end paths and surface known answers.
- **Writing code.** Query production while you build to confirm your code is designed for real scale, properly instrumented, SLO-measurable, and well tested.
- **Compounding context.** The more your team uses it, the easier future investigations become — every confirmed or corrected hypothesis sharpens the next retrieval.

Every retrieval is attributed and verifiable — the agent tells you who did the investigation, when, and links to the original tickets so you can read the evidence before acting.

## Examples

**Checkout latency spikes**

> You ask your coding agent about checkout latency spikes in payments, using `memory_search`.
>
> It responds: *Priya traced these same checkout latency spikes in the payments service on May 14 (PAY-4821). They lined up with a retry storm from the orders service after a failed deploy, not the database, which was the first suspect. I can open her ticket, or pull the same signals against the current incident. Which would help more?*

**Intermittent 502s**

> You prompt your agent to troubleshoot intermittent connections, using `memory_search`.
>
> It responds: *Justin escalated these intermittent 502s and connection resets to the network team twice last quarter (NET-1102, NET-1187). Both ran for several days and found nothing on the network side; the cause was connection-pool exhaustion in the service itself. Want me to link those tickets, or skip the network path and look at the pool first?*

## Tools your agent gets

The brew install exposes memory + skills MCP tools (no Quickwit log search in this trial).

| Tool | What it does |
|------|--------------|
| `memory_save` | Write a typed investigation record, keyed to the service and attributed to you. |
| `memory_search` | Hybrid (vector + lexical) search on symptoms, services, and entities. Use this at the start of any investigation. |
| `memory_record_outcome` | Mark a hypothesis confirmed, corrected, or ruled out. Sharpens future retrieval. |
| `memory_fetch_body` | Read the full body of a specific memory. |
| `memory_list_recent` | Show recent memories — useful for picking up where someone left off. |
| `memory_get_related` | Find memories linked to a given one. |
| `list_toko_skills` / `load_toko_skill` | Discover and load operational skills (runbooks, investigation patterns). |

## Install

```bash
brew install tokonoma-ai/tap/tokonoma
brew services start tokonoma
```

Installs `postgresql@18`, `pgvector`, and `ollama` via Homebrew, bootstraps the database, pulls the `nomic-embed-text` embedding model on first start, and exposes an MCP endpoint at `http://127.0.0.1:8765/mcp`.

First start takes a couple of minutes — it's pulling a ~270MB model and bootstrapping postgres.

### Wire it into your agent

**Claude Code:**

```bash
claude mcp add --transport http tokonoma http://127.0.0.1:8765/mcp
```

**Cursor** — add to `~/.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "tokonoma": {
      "url": "http://127.0.0.1:8765/mcp"
    }
  }
}
```

**Codex CLI** — add to `~/.codex/config.toml`:

```toml
[mcp_servers.tokonoma]
url = "http://127.0.0.1:8765/mcp"
```

### Verify it's working

Confirm your agent sees Tokonoma and the server is healthy:

```bash
claude mcp list                        # should include: tokonoma  http://127.0.0.1:8765/mcp
curl http://127.0.0.1:8765/health      # should return: ok
```

Then ask your agent: *"List recent memories from Tokonoma."* It should call `memory_list_recent` and return an empty list — that's expected before you've saved anything.

If something doesn't look right, see [Troubleshooting](#troubleshooting).

### Pre-populate memory

Ask your agent:

> run /onboard from tokonoma-mcp

This builds memories from existing material — tickets, docs, RCAs, runbooks. Anything that captures how your team thinks through production problems is usable seed material.

## Try these prompts

**At the start of an investigation**

- *"Search Tokonoma for past incidents on the payments service."*
- *"What recent memories do we have about the checkout flow?"*
- *"Find memories related to PAY-4821."*

**While writing or reviewing code**

- *"I'm about to add retries here — have we hit retry storm issues before?"*
- *"Any memories about SLO violations for this service?"*
- *"Load the investigation-prior-art skill from Tokonoma — I want to see if we've hit something like this before."*

**Closing out an investigation**

- *"Save this investigation to Tokonoma: [paste your notes]."*
- *"Mark the connection-pool hypothesis as confirmed for incident NET-1187."*

## Troubleshooting

**Service won't start.** Check the bootstrap logs:

- `~/.tokonoma/supervisor.log` — postgres init, ollama model pull, subprocess errors
- `~/.tokonoma/logs/toko-mcp.log` — MCP server logs (populated after bootstrap completes)

**MCP endpoint not responding.** Confirm the service is up:

```bash
brew services list | grep tokonoma     # should show "started"
curl http://127.0.0.1:8765/health      # should return "ok"
```

**Port 8765 already in use.** The brew service binds 8765 and the port isn't configurable from the CLI. Find what's holding it with `lsof -i :8765` and stop that process before restarting.

**Tools don't appear in your agent.** In Claude Code, `claude mcp list` should show the tokonoma entry on `http://127.0.0.1:8765/mcp`. If the entry's missing, re-run `claude mcp add` with `--transport http`. If it's there but the agent doesn't see the tools, restart the agent session.

**Everything's broken, start fresh.** `tokonoma-reset` drops the DB, the ollama model, and `~/.tokonoma/` — then `brew services restart tokonoma` re-bootstraps from scratch. Heads-up: this doesn't stop the `postgresql@18` or `ollama` brew services, so they keep running in the background. To stop them too, run `brew services stop postgresql@18 ollama` — but skip this if other tools on your Mac share them.

## Formulas

| Formula    | Description                                                     |
| ---------- | --------------------------------------------------------------- |
| `tokonoma` | toko-mcp local trial: memory + runbook-skill MCP tools, no Quickwit |

## Releases

`Formula/tokonoma.rb` is updated automatically by a release workflow in [tokonoma-ai/tokonoma-mcp](https://github.com/tokonoma-ai/tokonoma-mcp) on every release. Don't edit it by hand — your changes will be overwritten on the next release.

## Uninstall

```bash
tokonoma-reset           # drop the DB, ollama model, ~/.tokonoma/
brew services stop tokonoma
brew uninstall tokonoma
brew untap tokonoma-ai/tap
```

`postgresql@18` and `ollama` are not uninstalled — they may be in use by other tools.
