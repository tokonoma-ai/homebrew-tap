# Tokonoma Homebrew Tap

Local-trial distribution for [tokonoma-mcp](https://github.com/tokonoma-ai/tokonoma-mcp) — the toko-mcp MCP server (memory + skill tools) packaged for a one-command Mac install.

## Install

```bash
brew install tokonoma-ai/tap/tokonoma
brew services start tokonoma
```

This installs `postgresql@16`, `pgvector`, and `ollama` via Homebrew, bootstraps the database and pulls the `nomic-embed-text` embedding model on first start, and exposes an MCP endpoint at `http://127.0.0.1:8000/mcp`. Run `brew info tokonoma` after install for Claude Code / Cursor / Codex wiring snippets.

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

`postgresql@16` and `ollama` are not uninstalled — they may be in use by other tools.
