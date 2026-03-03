#!/usr/bin/env bash
set -euo pipefail

API_BASE="${FJ_API_BASE:-https://fluffyjaws.adobe.com}"
PROJECT_DIR="$(pwd)"
DRY_RUN=0
RUN_VERIFY=0
SKIP_INSTALL=0
WIZARD=0
DRY_RUN_SET=0
RUN_VERIFY_SET=0
SKIP_INSTALL_SET=0
PROJECT_DIR_SET=0
API_BASE_SET=0
declare -a IDES=()

usage() {
  cat <<'EOF'
Usage:
  ./scripts/setup-fluffy-mcp.sh --ide <cursor|claude-code|claude-desktop|codex|all> [options]
  ./scripts/setup-fluffy-mcp.sh               # interactive wizard

Options:
  --ide <name>         Target IDE/host. Repeatable.
  --project-dir <dir>  Project directory for project-level Cursor config (default: current dir).
  --api <url>          FluffyJaws API base URL (default: https://fluffyjaws.adobe.com).
  --dry-run            Show planned changes without writing files.
  --skip-install       Do not auto-run install when fj is missing.
  --verify             Run built-in verification after setup.
  --wizard             Force interactive wizard mode.
  -h, --help           Show this help.

Examples:
  ./scripts/setup-fluffy-mcp.sh
  ./scripts/setup-fluffy-mcp.sh --ide cursor
  ./scripts/setup-fluffy-mcp.sh --ide claude-code --ide codex --verify
  ./scripts/setup-fluffy-mcp.sh --ide all --dry-run
EOF
}

log() {
  echo "==> $*"
}

warn() {
  echo "WARNING: $*" >&2
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

add_ide() {
  local ide="$1"
  case "$ide" in
    cursor|claude-code|claude-desktop|codex|all)
      IDES+=("$ide")
      ;;
    *)
      die "Unknown IDE '$ide'. Expected: cursor, claude-code, claude-desktop, codex, all."
      ;;
  esac
}

prompt_yes_no() {
  local prompt="$1"
  local default="$2"
  local suffix answer normalized

  if [[ "$default" == "y" ]]; then
    suffix="[Y/n]"
  else
    suffix="[y/N]"
  fi

  while true; do
    read -r -p "$prompt $suffix: " answer
    normalized="$(printf '%s' "${answer:-}" | tr '[:upper:]' '[:lower:]')"
    if [[ -z "$normalized" ]]; then
      normalized="$default"
    fi
    case "$normalized" in
      y|yes)
        return 0
        ;;
      n|no)
        return 1
        ;;
      *)
        echo "Please answer y or n."
        ;;
    esac
  done
}

run_wizard() {
  local raw_selection token
  local wizard_needs_project_dir=0
  local -a tokens

  echo
  echo "FluffyJaws MCP Setup Wizard"
  echo "---------------------------"
  echo "Select IDE(s) to configure:"
  echo "  1) cursor"
  echo "  2) claude-code"
  echo "  3) claude-desktop"
  echo "  4) codex"
  echo "  5) all"
  echo
  read -r -p "Selection (comma-separated) [5]: " raw_selection
  raw_selection="${raw_selection:-5}"

  # Normalize separators to commas and split.
  raw_selection="$(printf '%s' "$raw_selection" | tr ' ' ',')"
  IFS=',' read -r -a tokens <<< "$raw_selection"

  IDES=()
  for token in "${tokens[@]}"; do
    token="$(printf '%s' "$token" | tr '[:upper:]' '[:lower:]')"
    [[ -n "$token" ]] || continue
    case "$token" in
      1|cursor) add_ide "cursor" ;;
      2|claude-code|claudecode) add_ide "claude-code" ;;
      3|claude-desktop|claudedesktop) add_ide "claude-desktop" ;;
      4|codex) add_ide "codex" ;;
      5|all) add_ide "all" ;;
      *)
        die "Invalid wizard selection token '$token'."
        ;;
    esac
  done

  if [[ ${#IDES[@]} -eq 0 ]]; then
    die "No IDE selected in wizard."
  fi

  for token in "${IDES[@]}"; do
    case "$token" in
      cursor|all)
        wizard_needs_project_dir=1
        break
        ;;
    esac
  done

  if [[ "$PROJECT_DIR_SET" -eq 0 && "$wizard_needs_project_dir" -eq 1 ]]; then
    read -r -p "Project directory for Cursor project config [$PROJECT_DIR]: " raw_selection
    if [[ -n "${raw_selection:-}" ]]; then
      PROJECT_DIR="$raw_selection"
    fi
  fi

  if [[ "$RUN_VERIFY_SET" -eq 0 ]]; then
    if prompt_yes_no "Run verification after setup?" "y"; then
      RUN_VERIFY=1
    else
      RUN_VERIFY=0
    fi
  fi

  if [[ "$DRY_RUN_SET" -eq 0 ]]; then
    if prompt_yes_no "Dry-run only (do not write changes)?" "n"; then
      DRY_RUN=1
    else
      DRY_RUN=0
    fi
  fi

  if [[ "$SKIP_INSTALL_SET" -eq 0 ]]; then
    if prompt_yes_no "Auto-install fj if missing?" "y"; then
      SKIP_INSTALL=0
    else
      SKIP_INSTALL=1
    fi
  fi

  echo
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ide)
      [[ $# -ge 2 ]] || die "--ide requires a value."
      add_ide "$2"
      shift 2
      ;;
    --project-dir)
      [[ $# -ge 2 ]] || die "--project-dir requires a value."
      PROJECT_DIR="$2"
      PROJECT_DIR_SET=1
      shift 2
      ;;
    --api)
      [[ $# -ge 2 ]] || die "--api requires a value."
      API_BASE="$2"
      API_BASE_SET=1
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      DRY_RUN_SET=1
      shift
      ;;
    --skip-install)
      SKIP_INSTALL=1
      SKIP_INSTALL_SET=1
      shift
      ;;
    --verify)
      RUN_VERIFY=1
      RUN_VERIFY_SET=1
      shift
      ;;
    --wizard)
      WIZARD=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

if [[ "$WIZARD" -eq 1 ]]; then
  [[ -t 0 ]] || die "--wizard requires an interactive terminal."
  run_wizard
elif [[ ${#IDES[@]} -eq 0 ]]; then
  if [[ -t 0 ]]; then
    run_wizard
  else
    die "No --ide provided. Use --ide ... or run interactively for the wizard."
  fi
fi

if [[ " ${IDES[*]} " == *" all "* ]]; then
  IDES=("cursor" "claude-code" "claude-desktop" "codex")
fi

# De-duplicate while preserving order.
declare -a DEDUPED=()
for ide in "${IDES[@]:-}"; do
  found=0
  for existing in "${DEDUPED[@]:-}"; do
    if [[ "$existing" == "$ide" ]]; then
      found=1
      break
    fi
  done
  if [[ "$found" -eq 0 ]]; then
    DEDUPED+=("$ide")
  fi
done
IDES=("${DEDUPED[@]}")

PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

if ! command -v curl >/dev/null 2>&1; then
  die "curl is required."
fi

if ! command -v python3 >/dev/null 2>&1; then
  die "python3 is required."
fi

log "Checking Adobe network/VPN reachability..."
if ! curl -fsSL "$API_BASE/" -o /dev/null 2>/dev/null; then
  die "Cannot reach $API_BASE. Connect to Adobe VPN and retry."
fi

ensure_fj() {
  if command -v fj >/dev/null 2>&1; then
    return
  fi

  if [[ "$SKIP_INSTALL" -eq 1 ]]; then
    die "fj not found and --skip-install was set."
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] fj not found. Would run official fj installer command."
    return
  fi

  log "fj not found. Running official fj installer..."
  # Official Adobe FluffyJaws CLI installer command (verbatim).
  API_BASE=https://fluffyjaws.adobe.com; if curl -fsSL "$API_BASE/" -o /dev/null 2>/dev/null; then curl -fsSL "$API_BASE/api/cli/install.sh" | bash; else echo "VPN required. Connect to VPN and retry." >&2; false; fi

  if ! command -v fj >/dev/null 2>&1; then
    die "Install finished, but 'fj' is still not on PATH. Open a new shell and retry."
  fi
}

merge_mcp_json() {
  local config_path="$1"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] Would configure $config_path"
    return
  fi

  python3 - "$config_path" "$API_BASE" <<'PY'
import json
import os
import sys

path = os.path.expanduser(sys.argv[1])
api = sys.argv[2]

data = {}
if os.path.exists(path):
    raw = open(path, "r", encoding="utf-8").read().strip()
    if raw:
        try:
            data = json.loads(raw)
        except json.JSONDecodeError as exc:
            print(f"ERROR: {path} is not valid JSON: {exc}", file=sys.stderr)
            sys.exit(2)
if not isinstance(data, dict):
    print(f"ERROR: {path} must contain a top-level JSON object.", file=sys.stderr)
    sys.exit(2)

mcp = data.get("mcpServers")
if mcp is None:
    mcp = {}
elif not isinstance(mcp, dict):
    print(f"ERROR: {path} has non-object mcpServers value.", file=sys.stderr)
    sys.exit(2)

mcp["fluffyjaws"] = {
    "command": "fj",
    "args": ["mcp", "--api", api],
}
data["mcpServers"] = mcp

parent = os.path.dirname(path)
if parent:
    os.makedirs(parent, exist_ok=True)
tmp = path + ".tmp"
with open(tmp, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
os.replace(tmp, path)
print(path)
PY
}

setup_cursor() {
  local global_path="$HOME/.cursor/mcp.json"
  local project_path="$PROJECT_DIR/.cursor/mcp.json"
  log "Configuring Cursor (global + project)..."
  merge_mcp_json "$global_path"
  merge_mcp_json "$project_path"
}

setup_claude_code() {
  local path="$HOME/.claude.json"
  log "Configuring Claude Code..."
  merge_mcp_json "$path"
}

detect_claude_desktop_config() {
  if [[ -n "${CLAUDE_DESKTOP_CONFIG:-}" ]]; then
    echo "$CLAUDE_DESKTOP_CONFIG"
    return
  fi

  case "$(uname -s)" in
    Darwin)
      echo "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
      ;;
    Linux)
      echo "$HOME/.config/Claude/claude_desktop_config.json"
      ;;
    *)
      if [[ -n "${APPDATA:-}" ]]; then
        echo "$APPDATA/Claude/claude_desktop_config.json"
      else
        echo "$HOME/.config/Claude/claude_desktop_config.json"
      fi
      ;;
  esac
}

setup_claude_desktop() {
  local path
  path="$(detect_claude_desktop_config)"
  log "Configuring Claude Desktop ($path)..."
  merge_mcp_json "$path"
}

resolve_codex_bin() {
  if command -v codex >/dev/null 2>&1; then
    command -v codex
    return
  fi

  if [[ -x "/Applications/Codex.app/Contents/Resources/codex" ]]; then
    echo "/Applications/Codex.app/Contents/Resources/codex"
    return
  fi

  return 1
}

setup_codex() {
  local codex_bin
  if ! codex_bin="$(resolve_codex_bin)"; then
    warn "Codex binary not found. Skipping Codex setup."
    return
  fi

  log "Configuring Codex MCP server using $codex_bin..."

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] Would run: $codex_bin mcp remove fluffyjaws (if present)"
    log "[dry-run] Would run: $codex_bin mcp add fluffyjaws -- fj mcp --api $API_BASE"
    return
  fi

  if "$codex_bin" mcp get fluffyjaws >/dev/null 2>&1; then
    "$codex_bin" mcp remove fluffyjaws >/dev/null
  fi
  "$codex_bin" mcp add fluffyjaws -- fj mcp --api "$API_BASE"
}

run_chat_smoke_test() {
  local expected="FluffyJaws MCP is installed correctly"
  local prompt="Say 'FluffyJaws MCP is installed correctly' and nothing else."
  local output

  log "Running chat smoke test..."
  output="$(fj chat "$prompt" 2>&1 || true)"
  if [[ "$output" != *"$expected"* ]]; then
    echo "$output" >&2
    die "Chat smoke test failed."
  fi
}

run_mcp_healthcheck() {
  log "Running MCP health check..."
  python3 - "$API_BASE" <<'PY'
import json
import select
import subprocess
import sys
import time

api_base = sys.argv[1]
cmd = ["fj", "mcp", "--api", api_base]

p = subprocess.Popen(
    cmd,
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)

def send(msg):
    body = json.dumps(msg, separators=(",", ":")).encode("utf-8")
    frame = f"Content-Length: {len(body)}\r\n\r\n".encode("ascii") + body
    p.stdin.write(frame)
    p.stdin.flush()

def read_message(timeout=20):
    end = time.time() + timeout
    buf = b""
    while time.time() < end:
        readable, _, _ = select.select([p.stdout], [], [], 0.25)
        if not readable:
            continue
        chunk = p.stdout.read1(65536)
        if not chunk:
            break
        buf += chunk
        if b"\r\n\r\n" not in buf:
            continue
        header, rest = buf.split(b"\r\n\r\n", 1)
        content_length = None
        for line in header.split(b"\r\n"):
            if line.lower().startswith(b"content-length:"):
                content_length = int(line.split(b":", 1)[1].strip())
                break
        if content_length is None:
            raise RuntimeError("MCP response missing Content-Length header.")
        while len(rest) < content_length and time.time() < end:
            readable2, _, _ = select.select([p.stdout], [], [], 0.25)
            if not readable2:
                continue
            rest += p.stdout.read1(65536)
        if len(rest) < content_length:
            raise RuntimeError("Incomplete MCP frame received.")
        body = rest[:content_length]
        return json.loads(body.decode("utf-8"))
    raise TimeoutError("Timed out waiting for MCP response.")

try:
    send(
        {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2025-03-26",
                "capabilities": {},
                "clientInfo": {"name": "fj-healthcheck", "version": "1.0.0"},
            },
        }
    )
    init_reply = read_message()
    if init_reply.get("id") != 1 or "result" not in init_reply:
        raise RuntimeError(f"Unexpected initialize reply: {init_reply}")

    send({"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}})
    tools_reply = read_message()
    if tools_reply.get("id") != 2 or "result" not in tools_reply:
        raise RuntimeError(f"Unexpected tools/list reply: {tools_reply}")

    tools = tools_reply.get("result", {}).get("tools", [])
    names = [t.get("name") for t in tools if isinstance(t, dict)]
    if not names:
        raise RuntimeError("MCP tools/list returned 0 tools.")
    if "fluffyjaws_chat" not in names:
        raise RuntimeError("fluffyjaws_chat was not found in tools/list response.")

    print(f"MCP health check passed. Tools discovered: {len(names)}")
    print("fluffyjaws_chat is available.")
finally:
    try:
        p.terminate()
        p.wait(timeout=3)
    except Exception:
        try:
            p.kill()
        except Exception:
            pass
PY
}

run_full_verify() {
  log "Running built-in verification..."

  if ! command -v fj >/dev/null 2>&1; then
    die "fj not found after setup."
  fi

  fj --help >/dev/null

  if ! fj whoami >/dev/null 2>&1; then
    die "No active fj session. Run 'fj login' and then re-run with --verify."
  fi

  run_chat_smoke_test
  run_mcp_healthcheck
  log "Verification complete."
}

ensure_fj

for ide in "${IDES[@]}"; do
  case "$ide" in
    cursor)
      setup_cursor
      ;;
    claude-code)
      setup_claude_code
      ;;
    claude-desktop)
      setup_claude_desktop
      ;;
    codex)
      setup_codex
      ;;
  esac
done

log "Setup complete for: ${IDES[*]}"

if [[ "$RUN_VERIFY" -eq 1 ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] Would run built-in verification (whoami + chat smoke + MCP health check)."
  else
    run_full_verify
  fi
fi

echo
echo "Next step:"
echo "  Restart your IDE/session so it reloads MCP configuration."
