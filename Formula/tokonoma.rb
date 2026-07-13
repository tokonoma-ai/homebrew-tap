# typed: false
# frozen_string_literal: true

# Formula/tokonoma.rb — canonical formula source. The release workflow
# (.github/workflows/release-please.yaml, bump-tap-formula job) copies this
# whole file to tokonoma-ai/homebrew-tap/Formula/tokonoma.rb on each release,
# substituting `version` + per-arch `url`/`sha256` via
# packaging/brew/bump_formula.py. Edit this file — not the tap copy.
class Tokonoma < Formula
  desc "Local trial of toko-mcp — MCP server for memory and procedure skills"
  homepage "https://tokonoma.ai"
  version "0.26.0"
  license "Proprietary"

  depends_on :macos
  # llama.cpp supplies llama-server, which Homebrew's ollama bottle (0.30.x)
  # omits — without it every GGUF request (including the embedding model)
  # fails and memory search silently degrades to lexical-only. supervisor.sh
  # bridges the binary into ollama's keg at each service start.
  # See Homebrew/homebrew-core#285982, ollama/ollama#16535.
  depends_on "llama.cpp"
  depends_on "ollama"
  depends_on "pgvector"
  depends_on "postgresql@18"

  on_macos do
    on_arm do
      url "https://github.com/tokonoma-ai/homebrew-tap/releases/download/v0.26.0/tokonoma-darwin-arm64.tar.gz"
      sha256 "9a4144d556d766c12ff6212129bfe14056f8638daf0df12c05a89e730b91db76"
    end
    on_intel do
      url "https://github.com/tokonoma-ai/homebrew-tap/releases/download/v0.26.0/tokonoma-darwin-amd64.tar.gz"
      sha256 "c82e5f429b669952fa44d0da49b55e78ce78f7affc1927a7eaf98941f0fe65d3"
    end
  end

  def install
    libexec.install "tokonoma-mcp"
    libexec.install "supervisor.sh"
    bin.install "tokonoma-reset"
    # Claude Code ambient-visibility helpers. Installed on PATH but NEVER
    # wired into settings.json by the package; the onboard skill offers
    # them as explicit, previewed opt-ins. See docs/session-receipts.md.
    bin.install "tokonoma-receipt"
    bin.install "tokonoma-statusline"
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

      Optional Claude Code extras: a Stop-hook session receipt
      (tokonoma-receipt) and a terminal statusline ticker
      (tokonoma-statusline) are on PATH but inactive. The onboard skill
      offers them as explicit opt-ins; nothing is wired automatically.

      To stop:                          brew services stop tokonoma
      To reset (drop DB + model):       tokonoma-reset

      To uninstall cleanly:
        tokonoma-reset             # drop DB, role, ollama model, ~/.tokonoma
        brew uninstall tokonoma    # also auto-removes ollama, postgresql@18,
                                   # and pgvector if nothing else needs them
        brew autoremove            # only if the deps above didn't get removed
                                   # (e.g. HOMEBREW_NO_AUTOREMOVE is set)
      If you opted into the Claude Code hook or statusline, also remove
      their entries from ~/.claude/settings.json (tokonoma-reset prints
      the exact keys).

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
      # No kubelet here — and a fixed livez port would collide across
      # concurrent test runs even though PORT is a free_port.
      "LIVEZ_PORT"       => "0",
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
