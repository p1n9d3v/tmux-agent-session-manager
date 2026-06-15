#!/usr/bin/env bash
# tmux-claude-session-manager
#
# List, monitor status, and jump across nested agent sessions from a
# single popup. tpm runs this file as an executable on tmux startup; it reads
# user options (with sensible defaults) and installs the key bindings.

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/helpers.sh
. "$CURRENT_DIR/scripts/helpers.sh"

launch_key="$(get_tmux_option @claude_launch_key 'y')"
codex_launch_key="$(get_tmux_option @codex_launch_key '')"
list_key="$(get_tmux_option @claude_list_key 'u')"

# Launch (or re-attach to) the active agent for the current pane's directory.
# #{pane_current_path} / #{window_id} are expanded by run-shell before the args
# reach the script.
tmux bind-key "$launch_key" \
  run-shell "$CURRENT_DIR/scripts/launch.sh '#{pane_current_path}' '#{window_id}'"

# Optional Codex-only launch key for users who run Claude and Codex side by side.
[ -n "$codex_launch_key" ] && tmux bind-key "$codex_launch_key" \
  run-shell "$CURRENT_DIR/scripts/launch.sh '#{pane_current_path}' '#{window_id}' 'codex'"

# Open the session picker. Capture the triggering client first (#{client_name})
# so the picker can move it to the chosen session's origin window.
tmux bind-key "$list_key" \
  run-shell "$CURRENT_DIR/scripts/list.sh '#{client_name}'"
