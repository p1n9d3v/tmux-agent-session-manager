# tmux-claude-session-manager

[![screenshot](./docs/screenshot.jpg)](https://youtu.be/NnTV6r4l5D0)

Run many [Claude Code](https://claude.com/claude-code) or
[Codex](https://developers.openai.com/codex) sessions across your
projects, each in its own tmux session — then **list them, see which are done
vs. still working, and jump to one** from a single popup.

If you launch coding agents per-directory (one nested session per project), you
quickly end up with a dozen of them and no way to tell which are finished without
opening each one. This plugin gives you:

- 🔢 **A central picker** (`prefix` + `u`) listing every running agent session.
- 🟢 **Live status** per session — `working` / `waiting` / `idle` — driven by
  Claude Code or Codex hooks, so you instantly see which need you.
- 👁️ **A live preview** of each session's screen right in the picker.
- 🎯 **Smart jump** — selecting a session switches your client to the window it
  was launched from, then resumes it in a popup over it.
- 🚀 **A launcher** (`prefix` + `y`) that opens/attaches the active agent for the
  current directory. Claude stays the default; Codex is opt-in.
- ❌ **Quick kill** (`ctrl-x`) of finished sessions from the picker.

Status is optional: without the hooks the picker still lists, previews, jumps,
and kills — sessions just show `?` instead of a color.

## Prerequisites

- **tmux ≥ 3.2** (for `display-popup`)
- **[fzf](https://github.com/junegunn/fzf)** — the picker UI
- **[Claude Code](https://claude.com/claude-code)** CLI (the `claude` command)
  or **[Codex](https://developers.openai.com/codex)** CLI (the `codex` command)
- bash; macOS or Linux

## Install (tpm)

Add to `~/.tmux.conf` (or `~/.config/tmux/tmux.conf`):

```tmux
set -g @plugin 'craftzdog/tmux-claude-session-manager'
```

Then hit `prefix` + <kbd>I</kbd> to install.

> **Keybinding note:** by default the plugin binds `prefix` + `y` (launch) and
> `prefix` + `u` (list). If your config binds those elsewhere, either change the
> options below, or make sure the plugin loads **after** your own bindings (put
> `run '~/.tmux/plugins/tpm/tpm'` _after_ them) so the one you want wins.

### Manual install

```sh
git clone https://github.com/craftzdog/tmux-claude-session-manager ~/clone/path
```

Add to `~/.tmux.conf`, then reload (`prefix` + <kbd>r</kbd> or `tmux source ~/.tmux.conf`):

```tmux
run-shell ~/clone/path/claude_session_manager.tmux
```

## Usage

| Key            | Action                                                                          |
| -------------- | ------------------------------------------------------------------------------- |
| `prefix` + `y` | Launch (or re-attach to) the active agent for the current directory, in a popup |
| `prefix` + `u` | Open the session picker                                                         |

Inside the picker:

| Key                       | Action                                                                    |
| ------------------------- | ------------------------------------------------------------------------- |
| `enter`                   | Jump to the session (switches to its origin window, resumes in the popup) |
| `ctrl-x`                  | Kill the highlighted session                                              |
| `↑` / `↓`, type to filter | fzf navigation                                                            |

Sessions needing your attention (`waiting`, `idle`) sort to the top.

Claude is the active agent by default. To make `prefix` + `y` launch Codex
instead:

```tmux
set -g @agent_active 'codex'
```

To use Claude and Codex side by side, leave Claude as the active agent and add a
Codex-only launch key:

```tmux
set -g @agent_active 'claude'
set -g @codex_launch_key 'Y'   # prefix + shift-y launches Codex
```

Then:

| Key            | Action                     |
| -------------- | -------------------------- |
| `prefix` + `y` | Launch/open Claude         |
| `prefix` + `Y` | Launch/open Codex          |
| `prefix` + `u` | Pick from all agent sessions |

## Claude status setup (optional, recommended)

Status comes from [Claude Code hooks](https://code.claude.com/docs/en/hooks)
that stamp each session's state onto its tmux session. Add the following to your
Claude Code settings (`~/.claude/settings.json`), merging into any existing
`hooks` block. Adjust the path if your plugins live elsewhere (e.g.
`~/.tmux/plugins/...`):

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.config/tmux/plugins/tmux-claude-session-manager/scripts/state.sh working"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "permission_prompt",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.config/tmux/plugins/tmux-claude-session-manager/scripts/state.sh waiting"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "AskUserQuestion",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.config/tmux/plugins/tmux-claude-session-manager/scripts/state.sh waiting"
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.config/tmux/plugins/tmux-claude-session-manager/scripts/state.sh idle"
          }
        ]
      }
    ]
  }
}
```

The state machine:

| Event                            | State        | Meaning                   |
| -------------------------------- | ------------ | ------------------------- |
| `UserPromptSubmit`               | 🔴 `working` | Busy — leave it           |
| `Notification` (permission)      | 🟡 `waiting` | Needs permission          |
| `PreToolUse` (`AskUserQuestion`) | 🟡 `waiting` | Asking you a question     |
| `Stop`                           | 🟢 `idle`    | Turn finished — your move |

> Claude Code reloads `hooks` dynamically — no restart needed. Sessions that are
> already running start reporting status on their next event once the hooks are
> added.

## Codex status setup (optional, recommended)

Codex can use the same `scripts/state.sh` hook target. Add this to
`~/.codex/hooks.json`, merging into any existing `hooks` block. Adjust the path
if your plugins live elsewhere:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.config/tmux/plugins/tmux-claude-session-manager/scripts/state.sh working"
          }
        ]
      }
    ],
    "PermissionRequest": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.config/tmux/plugins/tmux-claude-session-manager/scripts/state.sh waiting"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.config/tmux/plugins/tmux-claude-session-manager/scripts/state.sh idle"
          }
        ]
      }
    ]
  }
}
```

Codex requires new or changed hooks to be reviewed and trusted. Open `/hooks` in
Codex if it prints a hook trust warning.

The Codex state machine:

| Event              | State        | Meaning                   |
| ------------------ | ------------ | ------------------------- |
| `UserPromptSubmit` | 🔴 `working` | Busy — leave it           |
| `PermissionRequest` | 🟡 `waiting` | Needs permission          |
| `Stop`             | 🟢 `idle`    | Turn finished — your move |

## Options

Set any of these before the plugin loads (defaults shown):

```tmux
set -g @agent_active       'claude'   # active launch target: claude or codex
set -g @claude_launch_key     'y'        # prefix key: launch/open for current dir
set -g @codex_launch_key      ''         # optional Codex-only launch key, e.g. 'Y'
set -g @claude_list_key       'u'        # prefix key: open the picker
set -g @claude_command        'claude'   # command run in new sessions
set -g @claude_session_prefix 'claude-'  # tmux session name prefix
set -g @codex_command         'codex'    # command run in new Codex sessions
set -g @codex_session_prefix  'codex-'   # tmux session name prefix
set -g @claude_popup_width     '90%'     # popup width
set -g @claude_popup_height    '90%'     # popup height
```

## How it works

- The **launcher** creates a detached `<agent-prefix><hash-of-dir>` tmux session
  running the active agent command, records the window it came from, and attaches
  to it in a popup.
- The **hooks** set `@agent_state` / `@agent_state_at` on each session as the
  agent works. Claude compatibility keys are still written for old configs.
- The **picker** lists Claude and Codex sessions, reads their state and a live
  `capture-pane` preview, and on selection moves your client to the session's
  origin window before resuming it in the popup.
- Pressing `prefix` + `u` **from inside a session popup** detaches that popup
  first (closing it), then reopens the picker full-size on the outer host client —
  so you never end up with a cramped popup-in-popup.

## License

[MIT](LICENSE) © Takuya Matsuyama
