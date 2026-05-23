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
  version "0.10.0"
  license "Proprietary"

  depends_on :macos
  depends_on "ollama"
  depends_on "pgvector"
  depends_on "postgresql@18"

  on_macos do
    on_arm do
      url "https://github.com/tokonoma-ai/homebrew-tap/releases/download/v0.10.0/tokonoma-darwin-arm64.tar.gz"
      sha256 "18b59adfd5cccd1251fb255742c3161797c365f3992b7946d0d0df0574a9f091"
    end
    on_intel do
      url "https://github.com/tokonoma-ai/homebrew-tap/releases/download/v0.10.0/tokonoma-darwin-amd64.tar.gz"
      sha256 "e4a961c220ee629a0b4b6ad3c2af40d5943ecc5b40155a48193a1af267f82f04"
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
