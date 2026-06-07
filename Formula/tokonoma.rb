# typed: false
# frozen_string_literal: true

# Formula/tokonoma.rb — canonical formula source. The release workflow
# (.github/workflows/release-please.yaml, bump-tap-formula job) copies this
# whole file to tokonoma-ai/homebrew-tap/Formula/tokonoma.rb on each release,
# substituting `version` + per-arch `url`/`sha256` via
# packaging/brew/bump_formula.py. Edit this file — not the tap copy.
class Tokonoma < Formula
  desc "Local trial of toko-mcp — MCP server for memory and runbook skills"
  homepage "https://tokonoma.ai"
  version "0.15.0"
  license "Proprietary"

  depends_on :macos
  depends_on "ollama"
  depends_on "pgvector"
  depends_on "postgresql@18"

  on_macos do
    on_arm do
      url "https://github.com/tokonoma-ai/homebrew-tap/releases/download/v0.15.0/tokonoma-darwin-arm64.tar.gz"
      sha256 "64a2d5e5e1c18d37edac7ee534407599b664b553875728d2f013a76e1d6663c9"
    end
    on_intel do
      url "https://github.com/tokonoma-ai/homebrew-tap/releases/download/v0.15.0/tokonoma-darwin-amd64.tar.gz"
      sha256 "0bdd9d056dce73ebf370db63fd2a972df51b889c1799191edbf815bc46d225ea"
    end
  end

  def install
    libexec.install "tokonoma-mcp"
    libexec.install "supervisor.sh"
    bin.install "tokonoma-reset"
  end

  service do
    run [opt_libexec/"supervisor.sh", opt_libexec/"tokonoma-mcp"]
    keep_alive false
    working_dir HOMEBREW_PREFIX
    log_path var/"log/tokonoma.log"
    error_log_path var/"log/tokonoma.log"
  end

  def caveats
    <<~EOS
      tokonoma is installed. To start it:
        brew services start tokonoma

      MCP endpoint: http://127.0.0.1:8765/mcp

      Wire it into Claude Code:
        claude mcp add --transport http tokonoma http://127.0.0.1:8765/mcp

      Wire it into Claude Desktop — Settings → Developer → Edit Config
      opens ~/Library/Application Support/Claude/claude_desktop_config.json.
      Claude Desktop speaks stdio only, so route HTTP through mcp-remote
      (requires Node.js). Restart Claude Desktop after saving:
        {
          "mcpServers": {
            "tokonoma": {
              "command": "npx",
              "args": [
                "-y",
                "mcp-remote",
                "http://127.0.0.1:8765/mcp",
                "--transport",
                "http-only"
              ]
            }
          }
        }

      Wire it into Cursor — add to ~/.cursor/mcp.json:
        {
          "mcpServers": {
            "tokonoma": {
              "url": "http://127.0.0.1:8765/mcp"
            }
          }
        }

      Wire it into Codex CLI — add to ~/.codex/config.toml:
        [mcp_servers.tokonoma]
        url = "http://127.0.0.1:8765/mcp"

      To stop:                          brew services stop tokonoma
      To reset (drop DB + model):       tokonoma-reset

      To uninstall cleanly:
        tokonoma-reset             # drop DB, role, ollama model, ~/.tokonoma
        brew uninstall tokonoma    # also auto-removes ollama, postgresql@18,
                                   # and pgvector if nothing else needs them
        brew autoremove            # only if the deps above didn't get removed
                                   # (e.g. HOMEBREW_NO_AUTOREMOVE is set)

      If it doesn't come up, check:
        ~/.tokonoma/supervisor.log      bootstrap + subprocess errors
        ~/.tokonoma/logs/toko-mcp.log   server logs (after bootstrap)
    EOS
  end

  test do
    port = free_port
    env = {
      "PORT"             => port.to_s,
      "HOST"             => "127.0.0.1",
      "TOKO_MCP_LOG_DIR" => testpath.to_s,
    }
    pid = spawn(env, libexec/"tokonoma-mcp")
    begin
      # First-launch self-extraction is ~4 s; give it a comfortable margin.
      sleep 10
      assert_match "ok", shell_output("curl -fs http://127.0.0.1:#{port}/health")
    ensure
      Process.kill("TERM", pid)
      Process.wait(pid)
    end
  end
end
