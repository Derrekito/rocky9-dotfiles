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

- No TPM. Plugins are cloned at pinned commits and loaded with `run-shell` at
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

To update one, change its commit in `plugins.lock` and run `install.sh` again.
