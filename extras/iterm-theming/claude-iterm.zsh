# ~/.config/iterm/claude-iterm.zsh
# Auto theming for iTerm2 sessions: distinct tab color + prominent badge + title.
# Managed file. Safe to delete this file and its source line in ~/.zshrc to revert.
#
# What it does, automatically, on every prompt and every `cd`:
#   - Tab color  : a fixed, distinct color per session/tab (based on the iTerm2 session
#                  id), so every new tab differs and the color does NOT change as you cd.
#   - Badge      : big background label = current dir name + git branch (updates as you cd)
#   - Tab title  : dir name when idle; Claude Code overrides it with the task while running
#
# Manual overrides:
#   tabname My Label   pin a custom tab title for this session
#   tabcolor 1-12      force a specific color (e.g. if two tabs landed on the same one)

# Only inside iTerm2, interactive shells, and not inside tmux.
if [[ "$TERM_PROGRAM" == "iTerm.app" && -o interactive && -z "$TMUX" ]]; then

  # Curated palette of distinguishable, pleasant colors: "R G B".
  typeset -ga _CLAUDE_TAB_COLORS=(
    "214 69 65"     # red
    "222 105 49"    # orange
    "219 140 38"    # amber
    "201 167 39"    # gold
    "168 176 45"    # lime
    "120 173 58"    # green
    "74 170 96"     # emerald
    "57 171 126"    # teal
    "48 165 160"    # aqua
    "53 158 199"    # sky
    "66 122 214"    # blue
    "86 104 220"    # royal
    "121 96 209"    # indigo
    "148 92 210"    # violet
    "168 89 197"    # purple
    "196 84 188"    # orchid
    "204 86 158"    # magenta
    "210 80 120"    # rose
    "112 124 140"   # slate
    "94 158 122"    # sage
  )

  # Fixed color for THIS session (tab/pane), independent of the working dir.
  # Identity = iTerm2 session id (fallback tty, then cwd). Manual override via `tabcolor`.
  _claude_tab_color() {
    local n=${#_CLAUDE_TAB_COLORS[@]}
    local idx
    if [[ -n "$_CLAUDE_TAB_COLOR_IDX" ]]; then
      idx=$_CLAUDE_TAB_COLOR_IDX
    else
      local key="${ITERM_SESSION_ID:-${TTY:-$PWD}}"
      local sum=$(cksum <<< "$key" | cut -d' ' -f1)
      idx=$(( sum % n + 1 ))
    fi
    local rgb=(${(s: :)_CLAUDE_TAB_COLORS[$idx]})
    printf '\033]6;1;bg;red;brightness;%s\a'   "${rgb[1]}"
    printf '\033]6;1;bg;green;brightness;%s\a' "${rgb[2]}"
    printf '\033]6;1;bg;blue;brightness;%s\a'  "${rgb[3]}"
  }

  # Manually pick this tab's color (1-12), e.g. if two tabs hashed to the same one.
  tabcolor() {
    if [[ "$1" == <-> && "$1" -ge 1 && "$1" -le ${#_CLAUDE_TAB_COLORS[@]} ]]; then
      _CLAUDE_TAB_COLOR_IDX="$1"
      _claude_tab_color
    else
      print "usage: tabcolor <1-${#_CLAUDE_TAB_COLORS[@]}>"
    fi
  }

  # Short label for the current directory: "~" at $HOME, else the dir's basename.
  _claude_pwd_label() {
    if [[ "$PWD" == "$HOME" ]]; then print -r -- "~"; else print -r -- "${PWD:t}"; fi
  }

  # Badge = dir label + git branch (if any). Overridden in real time, even on the Default profile.
  _claude_badge() {
    local label="$(_claude_pwd_label)"
    local branch
    branch=$(git branch --show-current 2>/dev/null)
    [[ -n "$branch" ]] && label="${label}  ${branch}"
    local b64=$(printf '%s' "$label" | base64 | tr -d '\n')
    printf '\033]1337;SetBadgeFormat=%s\a' "$b64"
  }

  # Title: pinned name if set via `tabname`, else the dir label. Claude Code overrides while running.
  _claude_title() {
    local t="${_CLAUDE_TAB_TITLE:-$(_claude_pwd_label)}"
    printf '\033]0;%s\a' "$t"
  }

  # Pin a manual tab title for this session (survives until you run `tabname` again).
  tabname() {
    _CLAUDE_TAB_TITLE="$*"
    _claude_title
  }

  # Clear the manual pin and go back to automatic dir-based titles.
  tabname-auto() {
    unset _CLAUDE_TAB_TITLE
    _claude_title
  }

  _claude_iterm_apply() {
    _claude_tab_color
    _claude_badge
    # Title is left to Claude Code (it sets the session/task name shown in the tab).
    # `tabname` still lets you pin a manual name when you want one.
  }

  autoload -Uz add-zsh-hook
  add-zsh-hook precmd _claude_iterm_apply
  add-zsh-hook chpwd  _claude_iterm_apply
fi
