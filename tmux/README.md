# tmux config (tmux 3.2a)

A tmux configuration built around fzf pickers and per-keymap help popups,
adjusted for the tmux 3.2a that Rocky Linux 9 ships.

**The prefix is `C-Space`, not `C-b`.**

| File | Purpose |
|------|---------|
| `tmux.conf` | The configuration |
| `plugins.lock` | Plugins and the commits they're pinned to |
| `fzf-windows.sh` | fzf-backed window switcher |
| `help/*.sh` | Help popups, one per keymap group |

The top-level `install.sh` links this directory to `~/.config/tmux` (tmux 3.1+
reads `~/.config/tmux/tmux.conf`) and clones the plugins into `plugins/`.

## Differences from the tmux 3.3+ version

- No TPM. Plugins are installed at pinned commits from
  `vendor/tmux-plugins.tar.gz` (never cloned) and loaded with `run-shell` at
  the end of section 6. Order matters: resurrect before continuum, and
  rose-pine after the `@rose_pine_*` options.
- `allow-passthrough` and `pane-border-indicators` are 3.3+ options, set with
  `-gq` so 3.2a skips them silently. Inline images through tmux don't work on
  3.2a.

## Plugins

- `tmux-plugins/tmux-sensible`
- `tmux-plugins/tmux-resurrect`: persist sessions across reboots
- `tmux-plugins/tmux-continuum`: auto-save every 15 min
- `tmux-plugins/tmux-yank`: system clipboard
- `tmux-plugins/tmux-pain-control`
- `christoomey/vim-tmux-navigator`
- `rose-pine/tmux`: theme

To update one, change its commit in `plugins.lock`, run
`provision/fetch-vendor.sh` where it can download, copy `vendor/` over, and run
`install.sh` again.

## Restoring sessions

tmux-resurrect replays whatever each pane was running
(`@resurrect-processes ':all:'`), and its post-save hook,
`tmux-resurrect-agents.py`, rewrites panes running an AI agent (claude, codex,
grok, agy, opencode) so a restore resumes that pane's exact conversation. The
hook also refuses saves taken during shutdown or with no panes. If one slips
through anyway, `bin/tmux-attach` points resurrect's `last` back at the newest
save that has panes before it starts the server.

## Pane titles

- `prefix T`: name the current pane (prompt prefilled with its title).
- `prefix M-t`: show or hide titles on this window's pane borders.

A program that sets its own title (claude and codex do) overwrites a name set
by hand while `allow-rename` is on; `setw allow-rename off` in a window keeps
manual names there.
