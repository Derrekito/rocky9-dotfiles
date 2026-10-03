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
sudo dnf install -y neovim git make gcc gcc-c++ ripgrep unzip libicu pandoc
sudo dnf module install -y nodejs:22
```

`gcc`, `gcc-c++`, and `make` compile the treesitter parsers and
telescope-fzf-native. `ripgrep` powers live grep and multigrep. Mason needs
`unzip` for several servers and Node.js 18+ for `bashls` and `jsonls`. `libicu`
is for marksman, a .NET binary that aborts at startup without it. `pandoc` is
for `:MarkdownExport`.

Language servers install themselves. Mason is pinned to `clangd`,
`rust_analyzer`, `bashls`, `lua_ls`, `marksman`, `pylsp`, `jsonls`, `texlab`,
and `harper_ls`, and installs them on first launch.

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

Dropped, because they need Neovim 0.9 or newer: leetcode.nvim (and nui.nvim
with it), and 99. tree-sitter-manager.nvim is replaced by nvim-treesitter
v0.8.5.2. render-markdown.nvim is held at v3.3.1, the last release that runs
on 0.8 (with two aliases in `compat.lua` and its `WinResized` refresh dropped).

Not ported, because they need 0.9.4/0.10: snacks.nvim's inline images
(mermaid diagrams and math drawn in the buffer), the newer obsidian.nvim fork,
and clipboard image paste.

Behavior that changes on 0.8:

- Over SSH, paste returns the last copy from Neovim, because 0.8 can't read the
  terminal's clipboard. Copying still reaches your local clipboard through OSC 52.
- Floating windows lose their titles, such as harpoon's menu.
- `<leader>tt` opens Trouble v2's workspace diagnostics.
- vim-table-mode loads with the first Markdown buffer, as it did under lazy.nvim.
- obsidian.nvim skips vaults that don't exist on the machine.
- Markdown rendering is render-markdown v3: full-width heading bars, no
  language icon on code blocks, no link icons. `<leader>mt` (rendered/source)
  switches every markdown buffer at once, since v3 has only a global toggle.
- `:MarkdownGraph` shows the mermaid source of the graph, not a drawn diagram.
- `:MarkdownSlides` centers slides with the sign and fold columns (up to 27
  cells of margin), since 0.8 has no `statuscolumn`.

## Markdown

The same markdown setup as Derrekito/nvim (the cheatsheet's Markdown section
lists every key): rendering, list editing (bullets.vim), `]]`/`[[` heading
jumps and heading folds, `<leader>mb`/`mi`/`mc`/`m~`/`ml` formatting,
harper-ls grammar checking on prose, `:MarkdownGraph`, `:MarkdownSlides`, and
`:MarkdownExport`.

`:MarkdownExport` (`<leader>me`) converts a note to a PDF document, DOCX, or
PDF slides; the note's frontmatter `export:` block sets defaults (see the top
of `lua/config/export/init.lua`). What each needs on Rocky 9:

- DOCX: pandoc 2.14 from EPEL, installed by `provision/packages.sh`.
- PDF documents and slides: TeX Live 2020 and latexmk, from
  `sudo provision/export-tools.sh` (several hundred MB, so opt-in). Slides use
  the RosePineMoon Beamer theme's color/font/inner/outer parts from
  `../texmf/`, since the full theme needs minted, which Rocky doesn't package.
- Mermaid diagrams in any export: mermaid-cli on EPEL's headless Chromium, also
  from `export-tools.sh`. Without it, diagrams stay as code blocks.

Without a tool, `:MarkdownExport` names what's missing instead of failing.

## Layout

```
init.lua                entry point; ordered requires, nothing else
lua/compat.lua          newer Neovim APIs for 0.8; does nothing on newer versions
lua/config/plugins.lua  runs each lua/plugins/*.lua setup, in order
lua/config/keymaps.lua
lua/config/options.lua
lua/config/autocmds.lua
lua/osc52.lua           OSC 52 clipboard for Neovim < 0.10
lua/config/markdown*.lua  markdown helpers, :MarkdownGraph, :MarkdownSlides
lua/config/export/      :MarkdownExport (pandoc), with pandoc/export.lua
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
