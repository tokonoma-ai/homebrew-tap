# typed: false
# frozen_string_literal: true

# Formula/tokonoma.rb — the canonical formula source. The release workflow
# overwrites `version` and the per-arch `url`/`sha256` triples and commits the
# result to tokonoma-ai/homebrew-tap. Local builds use file:// URLs via the
# build-local helper.
class Tokonoma < Formula
  desc "Local trial of toko-mcp — MCP server for memory and runbook skills"
  homepage "https://tokonoma.ai"
  version "0.0.0-dev"
  license "Proprietary"

  depends_on :macos
  depends_on "ollama"
  depends_on "pgvector"
  depends_on "postgresql@16"

  on_macos do
    on_arm do
      url "https://github.com/tokonoma-ai/tokonoma-mcp/releases/download/v0.0.0-dev/tokonoma-darwin-arm64.tar.gz"
      sha256 "0000000000000000000000000000000000000000000000000000000000000000"
    end
    on_intel do
      url "https://github.com/tokonoma-ai/tokonoma-mcp/releases/download/v0.0.0-dev/tokonoma-darwin-amd64.tar.gz"
      sha256 "0000000000000000000000000000000000000000000000000000000000000000"
    end
  end

  def install
    # Release tarball layout:
    #   tokonoma-mcp/        # PyInstaller --onedir bundle (binary + libs)
    #   supervisor.sh
    #   tokonoma-reset
    libexec.install "tokonoma-mcp"
    libexec.install "supervisor.sh"
    bin.install "tokonoma-reset"
  end

  service do
    run [opt_libexec/"supervisor.sh", opt_libexec/"tokonoma-mcp/tokonoma-mcp"]
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
    require "open3"
    port = free_port
    env = {
      "PORT"             => port.to_s,
      "HOST"             => "127.0.0.1",
      "TOKO_MCP_LOG_DIR" => testpath.to_s,
    }
    pid = spawn(env, libexec/"tokonoma-mcp/tokonoma-mcp")
    begin
      # The PyInstaller onedir bundle takes ~1s to start; give it a bit more.
      sleep 5
      assert_match "ok", shell_output("curl -fs http://127.0.0.1:#{port}/health")
    ensure
      Process.kill("TERM", pid)
      Process.wait(pid)
    end
  end
end
