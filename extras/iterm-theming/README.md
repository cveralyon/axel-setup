# iTerm2 session theming (optional add-on)

Make every iTerm2 session easy to tell apart at a glance: a distinct, stable
**tab color** per session, a prominent **badge** (current directory + git
branch), and small convenience commands.

> **Scope: macOS + iTerm2 only.** This is the one AXEL component that writes
> outside `~/.claude`, so it is **not** run by `bootstrap.sh`. It is an explicit,
> opt-in extra you install by hand.

## What it does

- **Tab color per session.** Each tab gets a fixed color derived from its iTerm2
  session id, so every new tab differs and the color does not change as you `cd`.
  20-color palette.
- **Badge** (big background watermark) = current directory + git branch, updated
  as you navigate.
- **Tab title** is left to your foreground program. Claude Code, for example,
  sets the current task name. Use `tabname` to pin a custom one.
- **Opt-in "Claude" profile** (a dynamic profile that inherits your Default) with
  a bigger badge, *confirm before closing* (anti accidental close), unlimited
  scrollback, and only the session name in the tab (no `(job)` suffix).

## Install

```bash
bash extras/iterm-theming/install.sh            # install
bash extras/iterm-theming/install.sh --dry-run  # preview, change nothing
```

The installer is **idempotent** and **additive**:

- Copies `claude-iterm.zsh` to `~/.config/iterm/`.
- Copies the dynamic profile to `~/Library/Application Support/iTerm2/DynamicProfiles/`.
- Fetches iTerm2 shell integration (skip with `--skip-shell-integration`).
- Appends one guarded block to `~/.zshrc` (only once; a timestamped backup is
  made first).

To get the bigger badge + confirm-before-closing + unlimited scrollback, set the
profile as default once: **iTerm2 → Settings → Profiles → select "Claude" →
Other Actions → Set as Default**. The color, badge and commands work on any
profile regardless.

## Commands

| Command          | Effect                                                        |
|------------------|--------------------------------------------------------------|
| `tabname <name>` | Pin a fixed name for this tab (survives navigation).         |
| `tabname-auto`   | Clear the pin, back to the automatic directory name.         |
| `tabcolor <1-20>`| Force this tab's color (e.g. if two tabs hashed to the same).|

## Revert

Delete the marked block in `~/.zshrc` (or restore a `~/.zshrc.bak.*`), then
remove `~/.config/iterm/claude-iterm.zsh` and the dynamic profile
`~/Library/Application Support/iTerm2/DynamicProfiles/claude.json`.

## Notes

- iTerm2 cannot be configured to truncate long tab titles from the end (keeping
  the start); it always shows the tail. Keep titles short or use fewer/wider
  tabs if that matters to you.
- Nothing here contains secrets or machine-specific paths.
