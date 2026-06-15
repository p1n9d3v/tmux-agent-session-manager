#!/usr/bin/env bash
# Record an agent session's state on its tmux session, for the picker.
# Wire this into Claude Code or Codex hooks (see README):
#   state.sh <working|waiting|idle>
#
# Agent hooks inherit the process environment, so $TMUX_PANE is set whenever
# the agent runs inside tmux. Outside tmux this is a no-op.
[ -z "$TMUX_PANE" ] && exit 0

session=$(tmux display-message -p -t "$TMUX_PANE" '#{session_name}' 2>/dev/null) || exit 0
[ -z "$session" ] && exit 0

state="${1:-idle}"
now="$(date +%s)"
agent=$(tmux show-options -qv -t "$session" @agent_type 2>/dev/null)

tmux set-option -t "$session" @agent_state "$state"
tmux set-option -t "$session" @agent_state_at "$now"

# Compatibility for existing Claude hook configs and sessions.
if [ "$agent" = 'claude' ] || [ -z "$agent" ]; then
  tmux set-option -t "$session" @claude_state "$state"
  tmux set-option -t "$session" @claude_state_at "$now"
fi
exit 0
