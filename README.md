# FluffyJaws MCP Integration

Professional, production-ready integration of **Mr. FluffyJaws (FluffyJaws / FJ)** into MCP-capable LLM hosts using the official `fj` CLI.

This project configures FluffyJaws as a **tool server** for hosts like Cursor, Claude Desktop, Claude Code, Codex, and other MCP clients.

## Overview

FluffyJaws is an **Adobe internal-only** assistant optimized for retrieval and reasoning over internal systems (wikis, Jira, Dynamics, Slack, SharePoint, Cloud Manager, runbooks, and related Adobe context).

This integration:
- Uses the official MCP entrypoint: `fj mcp --api https://fluffyjaws.adobe.com`
- Keeps your primary coding model as the orchestrator
- Routes Adobe-internal questions to FluffyJaws only when needed
- Supports robust operation with clear failure handling

## Architecture

```text
Primary LLM Host (Cursor / Claude / Codex / etc.)
        |
        | MCP (stdio)
        v
fj mcp --api https://fluffyjaws.adobe.com
        |
        v
FluffyJaws Internal Backend (Adobe network)
```

## Prerequisites

- Adobe VPN / corp network connectivity
- Access to `https://fluffyjaws.adobe.com`
- `curl` + shell (`bash`)
- Internal entitlement/group access for FluffyJaws if required

## Quick Start

### 1) Install `fj` CLI (official)

```bash
API_BASE=https://fluffyjaws.adobe.com; if curl -fsSL "$API_BASE/" -o /dev/null 2>/dev/null; then curl -fsSL "$API_BASE/api/cli/install.sh" | bash; else echo "VPN required. Connect to VPN and retry." >&2; false; fi
```

### 2) Verify installation

```bash
command -v fj
fj --help
fj chat "Say 'FluffyJaws MCP is installed correctly' and nothing else."
```

### 3) Add MCP server (project-level Cursor example)

Create `.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "fluffyjaws": {
      "command": "fj",
      "args": ["mcp", "--api", "https://fluffyjaws.adobe.com"]
    }
  }
}
```

## Host Configuration

### Cursor

User-level: `~/.cursor/mcp.json`  
Project-level: `.cursor/mcp.json`

```json
{
  "mcpServers": {
    "fluffyjaws": {
      "command": "fj",
      "args": ["mcp", "--api", "https://fluffyjaws.adobe.com"]
    }
  }
}
```

### Claude Desktop

Typical config path:
- macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
- Windows: `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "fluffyjaws": {
      "command": "fj",
      "args": ["mcp", "--api", "https://fluffyjaws.adobe.com"]
    }
  }
}
```

### Claude Code

Config path:
- `~/.claude.json`

Top-level `mcpServers` entry:

```json
{
  "mcpServers": {
    "fluffyjaws": {
      "command": "fj",
      "args": ["mcp", "--api", "https://fluffyjaws.adobe.com"]
    }
  }
}
```

### Codex

Recommended:

```bash
codex mcp add fluffyjaws -- fj mcp --api https://fluffyjaws.adobe.com
codex mcp list
```

Equivalent `~/.codex/config.toml`:

```toml
[mcp_servers.fluffyjaws]
command = "fj"
args = ["mcp", "--api", "https://fluffyjaws.adobe.com"]
```

## Tool Routing Policy (Recommended)

Use FluffyJaws when the request needs Adobe-internal evidence:
- AEM / Experience Cloud troubleshooting
- Internal docs, runbooks, Slack, SharePoint, Jira, Dynamics
- Pipeline failure investigations and incident context

Do not use FluffyJaws for:
- Purely generic coding, math, writing, or public-only questions

Operational rule:
- Default to at most one FluffyJaws call per turn
- Make a second call only if first result is incomplete or user explicitly asks

## Conversation Continuity (Important)

FluffyJaws MCP calls are effectively single-turn from the host perspective.

To preserve continuity:
1. Keep local memory of prior FJ Q/A snippets.
2. On follow-ups, prepend a compact context summary into the next query.
3. Ask FluffyJaws to confirm/correct prior findings before extending conclusions.

Example follow-up format:

```text
Prior FluffyJaws context:
- [fact 1]
- [fact 2]
- [source hints]

New question:
[follow-up request]

Please confirm or correct prior findings, then provide updated recommendations.
```

## Reliability Defaults

Recommended production defaults:
- MCP startup timeout: `15s`
- Tool call timeout: `45s`
- Retry transient failures: `2` retries with backoff (`2s`, `5s`)
- No retries on permission/auth failures
- Circuit breaker: after `3` consecutive failures, pause auto-calls for `5 minutes`

Graceful fallback behavior:
- Continue with base model assistance
- Clearly disclose that Adobe-internal retrieval was unavailable

## Troubleshooting

### `fj: command not found`
- Confirm install path: `command -v fj`
- Ensure install directory is in `PATH`
- Restart shell

### Network / VPN errors
- Reconnect Adobe VPN
- Re-run preflight check:
  ```bash
  curl -fsSL https://fluffyjaws.adobe.com/ -o /dev/null && echo OK || echo FAIL
  ```

### Unauthorized / session expired
- Run login flow:
  ```bash
  fj login
  fj whoami
  ```

### MCP server not appearing in host
- Validate host config JSON/TOML syntax
- Restart the host application/session
- Confirm server registration (`codex mcp list` or host MCP diagnostics)

## Validation Checklist

- `fj --help` works
- `fj whoami` confirms active session
- Host lists `fluffyjaws` MCP server
- `fluffyjaws_chat` is discoverable in tools list
- A known internal query returns useful Adobe-context output
- VPN-down scenario yields clear fallback messaging

## Security and Scope

- Internal Adobe data may be sensitive: share outputs on a need-to-know basis.
- Treat FluffyJaws responses as evidence inputs to your final answer, not as an unverified ground truth.
- Do not assume OpenAI-compatible public endpoints; use official `fj` MCP integration only.

## Project Status

- `fj` CLI integration: configured
- MCP server wiring: configured for major hosts
- Production guidance: included in this README

