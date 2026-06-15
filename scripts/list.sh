#!/usr/bin/env bash
# Open the agent session picker in a popup.
# Arg: <client-name> of the triggering client (expanded by run-shell), stashed
# so the picker can move that client to the chosen session's origin window.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
. "$DIR/helpers.sh"

tmux set-option -g @agent_parent "${1:-}"
tmux set-option -g @claude_parent "${1:-}"

w="$(get_tmux_option @claude_popup_width '90%')"
h="$(get_tmux_option @claude_popup_height '90%')"
tmux display-popup -w "$w" -h "$h" -E "$DIR/picker.sh"
