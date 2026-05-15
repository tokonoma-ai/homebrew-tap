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
  version "0.6.0"
  license "Proprietary"

  depends_on :macos
  depends_on "ollama"
  depends_on "pgvector"
  depends_on "postgresql@18"

  on_macos do
    on_arm do
      url "https://github.com/tokonoma-ai/homebrew-tap/releases/download/v0.6.0/tokonoma-darwin-arm64.tar.gz"
      sha256 "3816b0a648d86113c5efa2cf6f6e79a217534df9fb938c55201e6bc52421c1ab"
    end
    on_intel do
      url "https://github.com/tokonoma-ai/homebrew-tap/releases/download/v0.6.0/tokonoma-darwin-amd64.tar.gz"
      sha256 "6eb87b1c32c26b834f27c5ed3eb64bf5370832359caf47da93f032d06d4aa798"
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
      Supervisor log:                   ~/.tokonoma/supervisor.log
      Server log:                       ~/.tokonoma/logs/toko-mcp.log
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
