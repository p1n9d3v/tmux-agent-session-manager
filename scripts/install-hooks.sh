#!/usr/bin/env bash
# Install Claude Code and Codex status hooks for tmux-agent-session-manager.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_SCRIPT="$DIR/state.sh"

install_claude=0
install_codex=0
dry_run=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [--all] [--claude] [--codex] [--dry-run]

Options:
  --all       Install both Claude Code and Codex hooks (default)
  --claude    Install Claude Code hooks in ~/.claude/settings.json
  --codex     Install Codex hooks in ~/.codex/hooks.json
  --dry-run   Print changes without writing files
  -h, --help  Show this help
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --all)
      install_claude=1
      install_codex=1
      ;;
    --claude)
      install_claude=1
      ;;
    --codex)
      install_codex=1
      ;;
    --dry-run)
      dry_run=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [ "$install_claude" -eq 0 ] && [ "$install_codex" -eq 0 ]; then
  install_claude=1
  install_codex=1
fi

if [ ! -f "$STATE_SCRIPT" ]; then
  printf 'Missing state script: %s\n' "$STATE_SCRIPT" >&2
  exit 1
fi

if [ "$dry_run" -eq 0 ] && [ ! -x "$STATE_SCRIPT" ]; then
  chmod +x "$STATE_SCRIPT"
fi

if ! command -v python3 >/dev/null 2>&1; then
  printf 'python3 is required to merge JSON hook files safely.\n' >&2
  exit 1
fi

export HOOK_STATE_SCRIPT="$STATE_SCRIPT"
export HOOK_INSTALL_CLAUDE="$install_claude"
export HOOK_INSTALL_CODEX="$install_codex"
export HOOK_DRY_RUN="$dry_run"

python3 <<'PY'
import copy
import json
import os
import shlex
import shutil
import sys
import tempfile
from datetime import datetime
from pathlib import Path

state_script = os.environ["HOOK_STATE_SCRIPT"]
install_claude = os.environ["HOOK_INSTALL_CLAUDE"] == "1"
install_codex = os.environ["HOOK_INSTALL_CODEX"] == "1"
dry_run = os.environ["HOOK_DRY_RUN"] == "1"


def command(state):
    return f"{shlex.quote(state_script)} {state}"


CLAUDE_RULES = {
    "UserPromptSubmit": [{"matcher": "", "hooks": [{"type": "command", "command": command("working")}]}],
    "Notification": [{"matcher": "permission_prompt", "hooks": [{"type": "command", "command": command("waiting")}]}],
    "PreToolUse": [{"matcher": "AskUserQuestion", "hooks": [{"type": "command", "command": command("waiting")}]}],
    "Stop": [{"matcher": "", "hooks": [{"type": "command", "command": command("idle")}]}],
}

CODEX_RULES = {
    "UserPromptSubmit": [{"hooks": [{"type": "command", "command": command("working")}]}],
    "PermissionRequest": [{"hooks": [{"type": "command", "command": command("waiting")}]}],
    "Stop": [{"hooks": [{"type": "command", "command": command("idle")}]}],
}


def load_json(path):
    if not path.exists():
        return {}

    text = path.read_text(encoding="utf-8")
    if not text.strip():
        return {}

    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"{path}: invalid JSON at line {exc.lineno}, column {exc.colno}: {exc.msg}")

    if not isinstance(data, dict):
        raise SystemExit(f"{path}: top-level JSON value must be an object")

    return data


def hook_command_exists(entries, wanted_command):
    for entry in entries:
        if not isinstance(entry, dict):
            continue
        hooks = entry.get("hooks")
        if not isinstance(hooks, list):
            continue
        for hook in hooks:
            if isinstance(hook, dict) and hook.get("type") == "command" and hook.get("command") == wanted_command:
                return True
    return False


def merge_rules(data, rules, path):
    hooks = data.setdefault("hooks", {})
    if not isinstance(hooks, dict):
        raise SystemExit(f"{path}: `hooks` must be a JSON object")

    changed = False
    added = []

    for event, rules_for_event in rules.items():
        entries = hooks.setdefault(event, [])
        if not isinstance(entries, list):
            raise SystemExit(f"{path}: `hooks.{event}` must be a JSON array")

        for rule in rules_for_event:
            wanted_command = rule["hooks"][0]["command"]
            if hook_command_exists(entries, wanted_command):
                continue
            entries.append(copy.deepcopy(rule))
            changed = True
            added.append(f"{event}: {wanted_command}")

    return changed, added


def write_json(path, data, existed):
    path.parent.mkdir(parents=True, exist_ok=True)
    if existed:
        stamp = datetime.now().strftime("%Y%m%d%H%M%S")
        backup = path.with_name(f"{path.name}.bak.{stamp}")
        shutil.copy2(path, backup)
        print(f"backup: {backup}")

    encoded = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path.parent, delete=False) as tmp:
        tmp.write(encoded)
        tmp_path = Path(tmp.name)
    os.replace(tmp_path, path)
    print(f"updated: {path}")


def install(name, path, rules):
    existed = path.exists()
    data = load_json(path)
    before = json.dumps(data, sort_keys=True, ensure_ascii=False)
    changed, added = merge_rules(data, rules, path)
    after = json.dumps(data, sort_keys=True, ensure_ascii=False)
    changed = changed and before != after

    if not changed:
        print(f"{name}: already installed in {path}")
        return

    if dry_run:
        print(f"{name}: would update {path}")
        for item in added:
            print(f"  add {item}")
        return

    write_json(path, data, existed)


home = Path.home()

if install_claude:
    install("Claude Code", home / ".claude" / "settings.json", CLAUDE_RULES)

if install_codex:
    install("Codex", home / ".codex" / "hooks.json", CODEX_RULES)

if install_codex and not dry_run:
    print("Codex may ask you to trust the hook. If prompted, open `/hooks` in Codex.")
PY
