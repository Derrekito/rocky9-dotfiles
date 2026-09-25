# nvim (Neovim 0.8)

My Neovim configuration, C++ first, with LaTeX, Markdown, and Lua along for the
ride. This copy runs on Neovim 0.8.0, the version EPEL ships for Rocky Linux 9.
There's no plugin manager: every plugin is pinned to a commit in `plugins.lock`
and installed by `install-plugins.sh`. It's a port of
[Derrekito/nvim](https://github.com/Derrekito/nvim), which targets Neovim 0.11+.

## Requirements

On Rocky Linux 9:

```bash
sudo dnf install -y epel-release
sudo dnf install -y neovim git make gcc gcc-c++ ripgrep unzip
sudo dnf module install -y nodejs:22
```

`gcc`, `gcc-c++`, and `make` compile the treesitter parsers and
telescope-fzf-native. `ripgrep` powers live grep and multigrep. Mason needs
`unzip` for several servers and Node.js 18+ for `bashls` and `jsonls`.

Language servers install themselves. Mason is pinned to `clangd`,
`rust_analyzer`, `bashls`, `lua_ls`, `marksman`, `pylsp`, `jsonls`, and
`texlab`, and installs them on first launch.

One exception: `cmake-language-server` comes from pipx and is expected on
`PATH`. Its virtualenv needs `pygls>=1.1.1,<2.0`, because pygls 2.x dropped the
import that server relies on.

Mason also installs the formatters and linters that conform.nvim and nvim-lint
call (the `tools` list in `lua/plugins/lsp-config.lua`). A few don't come from
Mason: `cppcheck` from EPEL and `clang-format` from `clang-tools-extra`, both
installed by `provision/packages.sh`.

## Install

The repo's top-level `install.sh` links this directory to `~/.config/nvim`
and runs `install-plugins.sh`. To do it by hand:

```bash
ln -s "$PWD" ~/.config/nvim
./install-plugins.sh
nvim
```

The script clones each plugin at its pinned commit into
`~/.local/share/nvim/site/pack/plugins/`, where Neovim loads it on its own. The
first launch then compiles treesitter parsers and installs language servers in
the background.

Two of the plugins are mine, [devdocs.nvim](https://github.com/Derrekito/devdocs.nvim)
and [diagnostic-picker.nvim](https://github.com/Derrekito/diagnostic-picker.nvim).
They install from GitHub like anything else. On a machine where a local checkout
exists under `~/devel` or `~/Projects`, the script symlinks that instead, so
edits are live.

## Updating plugins

Change a commit in `plugins.lock` and run `install-plugins.sh` again. Most pins
sit at the newest commit that still supports Neovim 0.8, and the comment on each
line says why it's pinned where it is, so moving one forward usually means
needing a newer Neovim.

Mason's package registry is pinned too, in `lua/plugins/lsp-config.lua`. To
update language servers, set a newer registry tag there and run `:MasonUpdate`.

## Differences from Derrekito/nvim

`lua/compat.lua` fills in the newer Neovim APIs that this config and its plugins
use, such as `vim.system`, `vim.uv`, `vim.fs.root`, `vim.lsp.get_clients`, and
`vim.diagnostic.jump`. Each one is added only when missing, so the file does
nothing on a newer Neovim. It also works around a Neovim 0.8.0 bug where asking
for a buffer's LSP clients crashes while a server is still starting.

Language servers are set up with `require("lspconfig").<server>.setup()`, since
`vim.lsp.config` is 0.11+.

Dropped, because they need Neovim 0.9 or newer: render-markdown.nvim,
leetcode.nvim (and nui.nvim with it), and 99. tree-sitter-manager.nvim is
replaced by nvim-treesitter v0.8.5.2.

Behavior that changes on 0.8:

- Over SSH, paste returns the last copy from Neovim, because 0.8 can't read the
  terminal's clipboard. Copying still reaches your local clipboard through OSC 52.
- Floating windows lose their titles, such as harpoon's menu.
- `<leader>tt` opens Trouble v2's workspace diagnostics.
- vim-table-mode loads with the first Markdown buffer, as it did under lazy.nvim.
- obsidian.nvim skips vaults that don't exist on the machine.

## Layout

```
init.lua                entry point; ordered requires, nothing else
lua/compat.lua          newer Neovim APIs for 0.8; does nothing on newer versions
lua/config/plugins.lua  runs each lua/plugins/*.lua setup, in order
lua/config/keymaps.lua
lua/config/options.lua
lua/config/autocmds.lua
lua/osc52.lua           OSC 52 clipboard for Neovim < 0.10
lua/plugins/            one file per plugin's setup
after/ftplugin/         per-filetype settings
queries/                treesitter query overrides
plugins.lock            pinned plugin commits
install-plugins.sh      installs everything in plugins.lock
```

Load order in `init.lua` is deliberate. `compat` runs first, so everything after
it can use the newer APIs. Keymaps run next because they set the leader key.
Options run after plugins so they override plugin defaults. Autocommands and
diagnostics run last.

## Colors

[Rosé Pine Moon](https://rosepinetheme.com), with a local palette override in
`lua/rose-pine-moon.lua`.
