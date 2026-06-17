#!/usr/bin/env bash
# Launch (or re-attach to) an agent session for a directory, shown in a popup.
# Args: <dir> [origin-window-id] [agent]   (expanded by run-shell in the binding)
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
. "$DIR/helpers.sh"

path="${1:-$PWD}"
window="${2:-}"

claude_prefix="$(get_tmux_option @claude_session_prefix 'claude-')"
codex_prefix="$(get_tmux_option @codex_session_prefix 'codex-')"
agent="${3:-$(get_tmux_option @agent_active 'claude')}"
case "$agent" in
  claude)
    prefix="$claude_prefix"
    cmd="$(get_tmux_option @claude_command 'claude')"
    ;;
  codex)
    prefix="$codex_prefix"
    cmd="$(get_tmux_option @codex_command 'codex')"
    ;;
  *)
    tmux display-message "tmux-agent-session-manager: unsupported @agent_active '$agent'"
    exit 0
    ;;
esac
w="$(get_tmux_option @claude_popup_width '90%')"
h="$(get_tmux_option @claude_popup_height '90%')"

session="${prefix}$(session_hash "$path")"

current_session="$(tmux display-message -p '#S' 2>/dev/null || true)"
current_agent="$(tmux show-options -qv -t "$current_session" @agent_type 2>/dev/null || true)"
if [ "$current_agent" = 'claude' ] ||
  [ "$current_agent" = 'codex' ] ||
  { [ -n "$claude_prefix" ] && [[ "$current_session" == "$claude_prefix"* ]]; } ||
  { [ -n "$codex_prefix" ] && [[ "$current_session" == "$codex_prefix"* ]]; }; then
  tmux display-message '🫪 Popup window already open'
  exit 0
fi

tmux has-session -t "$session" 2>/dev/null ||
  tmux new-session -d -s "$session" -c "$path" "$cmd"

# Record which window launched it, so the picker can jump back here later.
tmux set-option -t "$session" @agent_type "$agent"
[ -n "$window" ] && tmux set-option -t "$session" @agent_origin "$window"

# Compatibility for existing Claude session pickers/configs.
if [ "$agent" = 'claude' ] && [ -n "$window" ]; then
  tmux set-option -t "$session" @claude_origin "$window"
fi

tmux display-popup -w "$w" -h "$h" -E "tmux attach-session -t $session"
