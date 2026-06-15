#!/usr/bin/env bash
# Launch (or re-attach to) an agent session for a directory, shown in a popup.
# Args: <dir> [origin-window-id] [agent]   (expanded by run-shell in the binding)
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
. "$DIR/helpers.sh"

path="${1:-$PWD}"
window="${2:-}"

agent="${3:-$(get_tmux_option @agent_active 'claude')}"
case "$agent" in
  claude)
    prefix="$(get_tmux_option @claude_session_prefix 'claude-')"
    cmd="$(get_tmux_option @claude_command 'claude')"
    ;;
  codex)
    prefix="$(get_tmux_option @codex_session_prefix 'codex-')"
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

tmux has-session -t "$session" 2>/dev/null \
  || tmux new-session -d -s "$session" -c "$path" "$cmd"

# Record which window launched it, so the picker can jump back here later.
tmux set-option -t "$session" @agent_type "$agent"
[ -n "$window" ] && tmux set-option -t "$session" @agent_origin "$window"

# Compatibility for existing Claude session pickers/configs.
if [ "$agent" = 'claude' ] && [ -n "$window" ]; then
  tmux set-option -t "$session" @claude_origin "$window"
fi

tmux display-popup -w "$w" -h "$h" -E "tmux attach-session -t $session"
