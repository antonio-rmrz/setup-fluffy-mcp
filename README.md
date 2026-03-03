# FluffyJaws MCP Setup Kit

Interactive setup for FluffyJaws MCP across:
- Cursor
- Claude Code
- Claude Desktop
- Codex

Official MCP command used by all hosts:
- `fj mcp --api https://fluffyjaws.adobe.com`

## Prerequisites

- Adobe VPN / internal network access
- `curl` and `python3`
- Permission to use FluffyJaws internally

## Install (Recommended)

From this repo root, run with no parameters:

```bash
./scripts/setup-fluffy-mcp.sh
```

This launches the interactive wizard and guides setup end-to-end.
The script is Bash-first and will automatically re-exec with Bash if launched via `sh`.

Wizard behavior:
- Prompts for IDE(s) to configure (default: `all`)
- Prompts to run verification after setup (default: yes)
- Prompts whether to auto-install `fj` if missing (default: yes)
- If `cursor` is selected, prompts for project directory (default: current directory)

After completion:
1. Restart your IDE/session.
2. If prompted for auth, run `fj login` and run setup again with `--verify`.

## Non-Interactive Usage

For scripted or CI-like use:

```bash
./scripts/setup-fluffy-mcp.sh --ide all --verify
```

Common examples:

```bash
./scripts/setup-fluffy-mcp.sh --ide codex
./scripts/setup-fluffy-mcp.sh --ide cursor --ide claude-code --verify
./scripts/setup-fluffy-mcp.sh --wizard
```

## Usage

```bash
./scripts/setup-fluffy-mcp.sh --ide <cursor|claude-code|claude-desktop|codex|all> [options]
```

Options:
- `--ide <name>`: repeatable; choose one or more targets
- `--project-dir <dir>`: project path for project-level Cursor config (default: current dir)
- `--api <url>`: override API base (default `https://fluffyjaws.adobe.com`)
- `--skip-install`: do not auto-install `fj` if missing
- `--verify`: run built-in verification checks
- `--wizard`: force interactive wizard mode

## What `--verify` Checks

- `fj whoami` session check
- Chat smoke test:
  - `fj chat "Say 'FluffyJaws MCP is installed correctly' and nothing else."`
- MCP health check:
  - `initialize` + `tools/list`
  - confirms `fluffyjaws_chat` is available

## Where Config Is Written

### Cursor
- `~/.cursor/mcp.json`
- `<project>/.cursor/mcp.json`

### Claude Code
- `~/.claude.json` (top-level `mcpServers`)

### Claude Desktop
- macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
- Linux: `~/.config/Claude/claude_desktop_config.json`
- Windows: `%APPDATA%\\Claude\\claude_desktop_config.json` (when `APPDATA` is set)

### Codex
- Runs `codex mcp add fluffyjaws -- fj mcp --api https://fluffyjaws.adobe.com`
- Persists to `~/.codex/config.toml`

## Troubleshooting

### Connectivity

```bash
curl -fsSL https://fluffyjaws.adobe.com/ -o /dev/null && echo OK || echo FAIL
```

### Session missing

```bash
fj login
./scripts/setup-fluffy-mcp.sh --ide all --verify
```

### Non-interactive environment with no args

If run without parameters in a non-TTY environment, the script exits and asks for `--ide`.

## Security Notes

- FluffyJaws is Adobe internal-only.
- Treat output as internal context.
- Use official `fj` CLI MCP mode only.
