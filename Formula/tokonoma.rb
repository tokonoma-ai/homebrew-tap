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
  version "0.6.1"
  license "Proprietary"

  depends_on :macos
  depends_on "ollama"
  depends_on "pgvector"
  depends_on "postgresql@18"

  on_macos do
    on_arm do
      url "https://github.com/tokonoma-ai/homebrew-tap/releases/download/v0.6.1/tokonoma-darwin-arm64.tar.gz"
      sha256 "21d5184f69a5e0715eebeb0c0f91ea065a859c6da30348f1e0ca458534e4282f"
    end
    on_intel do
      url "https://github.com/tokonoma-ai/homebrew-tap/releases/download/v0.6.1/tokonoma-darwin-amd64.tar.gz"
      sha256 "21b820a6053a1059b3431184ef7db5ea7ea1c3681c8a4016bcf8664ae4e2140f"
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

      First start takes ~30 s (postgres bootstrap + ollama embedding-model pull).
      Subsequent starts are near-instant.

      MCP endpoint: http://127.0.0.1:8000/mcp

      Wire it into Claude Code:
        claude mcp add --transport http tokonoma http://127.0.0.1:8000/mcp

      Wire it into Cursor — add to ~/.cursor/mcp.json:
        {
          "mcpServers": {
            "tokonoma": {
              "url": "http://127.0.0.1:8000/mcp"
            }
          }
        }

      Wire it into Codex CLI — add to ~/.codex/config.toml:
        [mcp_servers.tokonoma]
        url = "http://127.0.0.1:8000/mcp"

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
