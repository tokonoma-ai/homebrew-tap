# Tokonoma Homebrew Tap

Local-trial distribution for [tokonoma-mcp](https://github.com/tokonoma-ai/tokonoma-mcp) — the toko-mcp MCP server (memory + skill tools) packaged for a one-command Mac install.

## Install

```bash
brew install tokonoma-ai/tap/tokonoma
brew services start tokonoma
```

This installs `postgresql@18`, `pgvector`, and `ollama` via Homebrew, bootstraps the database and pulls the `nomic-embed-text` embedding model on first start, and exposes an MCP endpoint at `http://127.0.0.1:8000/mcp`.

### Wire it into your agent

**Claude Code:**

```bash
claude mcp add --transport http tokonoma http://127.0.0.1:8000/mcp
```

**Cursor** — add to `~/.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "tokonoma": {
      "url": "http://127.0.0.1:8000/mcp"
    }
  }
}
```

**Codex CLI** — add to `~/.codex/config.toml`:

```toml
[mcp_servers.tokonoma]
url = "http://127.0.0.1:8000/mcp"
```

## Formulas

| Formula    | Description                                                     |
| ---------- | --------------------------------------------------------------- |
| `tokonoma` | toko-mcp local trial: memory + runbook-skill MCP tools, no Quickwit |

## Releases

`Formula/tokonoma.rb` is updated automatically by a release workflow in [tokonoma-ai/tokonoma-mcp](https://github.com/tokonoma-ai/tokonoma-mcp) on every release. Don't edit it by hand — your changes will be overwritten on the next release.

## Uninstall

```bash
tokonoma-reset             # drop DB, role, ollama model, ~/.tokonoma
brew uninstall tokonoma    # also auto-removes ollama, postgresql@18,
                           # and pgvector if nothing else needs them
brew autoremove            # only if the deps above didn't get removed
                           # (e.g. HOMEBREW_NO_AUTOREMOVE is set)
brew untap tokonoma-ai/tap # optional
```

Run `tokonoma-reset` *before* `brew uninstall tokonoma` — the reset script ships inside the formula, so uninstalling first removes it. Modern Homebrew (5.x) runs `brew autoremove` automatically as part of `brew uninstall`, which is why the heavy deps come off in one step; the explicit `brew autoremove` line is the fallback for users with `HOMEBREW_NO_AUTOREMOVE` set. Anything you separately ran `brew install` on (e.g. your own `ollama` install) is left alone.
