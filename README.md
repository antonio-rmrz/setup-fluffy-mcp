# FluffyJaws MCP Setup Kit

One script. Any IDE.

This kit configures FluffyJaws MCP correctly for:
- Cursor
- Claude Code
- Claude Desktop
- Codex

Official MCP entrypoint used everywhere:
- `fj mcp --api https://fluffyjaws.adobe.com`

## Quick Start

From this repo root:

```bash
./scripts/setup-fluffy-mcp.sh
```

This launches the interactive wizard where you select your IDE(s) and options.

For non-interactive/CI usage:

```bash
./scripts/setup-fluffy-mcp.sh --ide all --verify
```

Then restart your IDE/session.

## What `setup-fluffy-mcp.sh` Does

1. Checks VPN/internal reachability to `https://fluffyjaws.adobe.com`.
2. Installs `fj` automatically if missing (official installer command).
3. Writes/merges the right MCP config for the IDE you choose.
4. Optional verification (`--verify`, or selected in wizard):
   - `fj whoami` session check
   - chat smoke test
   - MCP protocol health check (`initialize` + `tools/list` + `fluffyjaws_chat`)

## Usage

```bash
./scripts/setup-fluffy-mcp.sh --ide <cursor|claude-code|claude-desktop|codex|all> [options]
```

Options:
- `--ide <name>`: repeatable; choose one or more targets
- `--project-dir <dir>`: project path for project-level Cursor config (default: current dir)
- `--api <url>`: override API base (default `https://fluffyjaws.adobe.com`)
- `--dry-run`: preview changes only
- `--skip-install`: do not auto-install `fj` if missing
- `--verify`: run built-in verification checks
- `--wizard`: force interactive wizard mode

Examples:

```bash
./scripts/setup-fluffy-mcp.sh --ide codex
./scripts/setup-fluffy-mcp.sh --ide cursor --ide claude-code
./scripts/setup-fluffy-mcp.sh --ide all --dry-run
./scripts/setup-fluffy-mcp.sh --wizard
```

## Where Config Is Written

### Cursor
- `~/.cursor/mcp.json`
- `<project>/.cursor/mcp.json`

### Claude Code
- `~/.claude.json` (top-level `mcpServers`)

### Claude Desktop
- macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
- Linux: `~/.config/Claude/claude_desktop_config.json`
- Windows: `%APPDATA%\\Claude\\claude_desktop_config.json` (if `APPDATA` is set)

### Codex
- Uses `codex mcp add fluffyjaws -- fj mcp --api https://fluffyjaws.adobe.com`
- Persists to `~/.codex/config.toml`

## Troubleshooting

### VPN/connectivity

```bash
curl -fsSL https://fluffyjaws.adobe.com/ -o /dev/null && echo OK || echo FAIL
```

### Session missing

```bash
fj login
./scripts/setup-fluffy-mcp.sh --ide all --verify
```

### Preview before writing files

```bash
./scripts/setup-fluffy-mcp.sh --ide all --dry-run
```

## Security Notes

- FluffyJaws is Adobe internal-only.
- Treat output as internal context.
- Use official `fj` CLI MCP mode only.
