# nvim

My Neovim configuration: C++ first, with Go, LaTeX, Markdown and Lua along for
the ride. It's the same config as [Derrekito/nvim](https://github.com/Derrekito/nvim),
on the same Neovim release with the same plugins at the same commits, set up
for Rocky Linux 9 without a plugin manager:

- **Neovim** is the official release build (0.12.5), not EPEL's 0.8.
  `install.sh` takes it from `../vendor/` (copied in by hand; it never
  downloads), checks its SHA256, and unpacks it under
  `~/.local/share/rocky9-dotfiles/`, with `nvim` linked into `~/.local/bin`. No
  root needed.
- **Plugins** are pinned to a commit each in `plugins.lock` and installed by
  `install-plugins.sh` as plain Neovim packages, from `../vendor/nvim-plugins.tar.gz`
  (copied in by hand; it never clones). There's no lazy.nvim.
- **The plugin specs** in `lua/plugins/` are Derrekito/nvim's lazy.nvim-format
  files, unchanged apart from the few differences below, so updates copy
  across. `lua/config/plugins.lua` runs them (see "How plugins load").

## Requirements

`provision/packages.sh` (dnf) and `install.sh` (from `../vendor/`) install all of
it. By hand on Rocky Linux 9:

```bash
sudo dnf install -y epel-release
sudo dnf install -y git make gcc gcc-c++ ripgrep unzip libicu go-toolset delve
sudo dnf module install -y nodejs:22
```

- **Compilers:** `gcc`, `gcc-c++` and `make` build the treesitter parsers and
  telescope-fzf-native.
- **ripgrep** powers live grep and multigrep.
- **Mason** needs `unzip` for several servers and Node.js 18+ for `bashls`,
  `jsonls` and markdownlint.
- **libicu** is for marksman, the markdown language server, a .NET binary that
  aborts at startup without it.
- **go-toolset** lets Mason build gopls and goimports; `delve` is the Go
  debugger.
- **The tree-sitter CLI**, which tree-sitter-manager.nvim builds parsers with,
  is another `vendor/` file installed by `install.sh`. It's pinned to 0.25.10,
  the newest release whose binary runs on Rocky 9's glibc 2.34.

Language servers install themselves on first launch (Mason): `clangd`,
`rust_analyzer`, `gopls`, `bashls`, `lua_ls`, `marksman`, `pylsp`, `jsonls`,
`texlab` and `harper_ls`, plus the formatters, linters and debug adapters listed
in `lua/config/mason_tools.lua`.

## Install

The repo's top-level `install.sh` links this directory to `~/.config/nvim`,
installs Neovim and tree-sitter, runs `install-plugins.sh`, and builds the
parsers. To redo just the plugins: `./install-plugins.sh`.

Updating from an older checkout (the Neovim 0.8 config) is the same command.
`install-plugins.sh` moves plugins that `plugins.lock` no longer lists out of
Neovim's package path, to `~/.local/share/nvim/plugins-unlisted/`, so they stop
loading. The old git-cloned plugins are replaced by the vendored copies, once.
EPEL's `neovim` can stay installed: `~/.local/bin/nvim` comes first on `PATH`.

## Updating plugins

Change a commit in `plugins.lock`, run `provision/fetch-vendor.sh` on a machine
that can download (it fetches only what changed), copy `vendor/` over, and run
`install-plugins.sh` again. A plugin whose vendored commit doesn't match the
lock stops the install with its name.

To pick up changes from Derrekito/nvim:

1. Copy its `lua/` files across.
2. Copy each plugin's commit from its `lazy-lock.json` into `plugins.lock`; the
   plugin names match.
3. Re-apply the differences listed below.

Your own plugins (Derrekito/*) use a local checkout under `~/devel` or
`~/Projects` when one exists, symlinked so edits are live, as lazy.nvim's dev
block does there; otherwise they come from `vendor/` like the rest.

## How plugins load

Neovim loads everything in `~/.local/share/nvim/site/pack/plugins/start/` by
itself. `lua/config/plugins.lua` then does what lazy.nvim would do with the
specs:

1. It runs every `init` first.
2. It runs `config(plugin, opts)`, or `require(<module>).setup(opts)` for a spec
   with only `opts`. Dependencies come first, then higher `priority`, then
   file order.
3. It maps `keys` entries that carry their own right-hand side.

Everything loads at startup: `ft`, `cmd`, `event` and `lazy` are ignored, and
`build` steps run in `install-plugins.sh`. Each spec runs under `pcall`, so a
broken one reports an error and the rest still load.

## Differences from Derrekito/nvim

- **Go support:** gopls (`lua/plugins/lsp-config.lua`), a delve adapter
  (`nvim-dap.lua`), the Go docset (`devdocs.lua`), the go/gomod/gosum/gowork
  parsers (`treesitter.lua`), and gofmt-style tabs (`after/ftplugin/go.lua`).
- **diagnostic-picker:** setup is kept quiet (`diagnostic-picker.lua`).
  Otherwise its "filter applied" notice would print on every launch, since
  plugins load at startup here instead of on `<leader>dg`.
- **No 99** (ThePrimeagen's AI plugin): not in `plugins.lock`, no spec, no
  `<leader>9*` keys.
- **Plugin loading:** `init.lua` runs `config.plugins` where Derrekito/nvim
  bootstraps lazy.nvim. There's no `lazy-lock.json`; `plugins.lock` replaces it.

## Markdown

The same markdown setup as Derrekito/nvim; the cheatsheet's Markdown section
lists every key.

- **Rendering:** render-markdown, plus inline images, mermaid diagrams and math
  through snacks.nvim. Inline images need a terminal with the kitty graphics
  protocol (Ghostty, kitty, WezTerm). Without one, they're simply not shown.
- **Editing:** list editing (bullets.vim), heading jumps and folds, and the
  formatting keys.
- **Tools:** harper-ls grammar checking, plus `:MarkdownGraph`,
  `:MarkdownSlides` and `:MarkdownExport`.

What `:MarkdownExport` (`<leader>me`) needs on Rocky 9:

- **DOCX:** pandoc 2.14 from EPEL, which `provision/packages.sh` installs when
  the repos have it.
- **PDF documents and slides:** TeX Live 2020 and latexmk, from
  `sudo provision/export-tools.sh` (opt-in, several hundred MB). Slides use the
  RosePineMoon Beamer theme parts in `../texmf/`.
- **Mermaid diagrams in exports:** mermaid-cli, also from `export-tools.sh`.

Without a tool, `:MarkdownExport` names what's missing instead of failing.

## Tests

- `tests/run.sh` runs Derrekito/nvim's suite: unit specs (no plugins) and smoke
  specs (the real config, every plugin). The specs check for lazy.nvim and
  test the pinned packages instead when it's absent.
- `../test/smoke.sh` runs that suite as one of its checks, alongside the
  markdown checks in `../test/markdown.lua` and the tmux and bash checks. CI
  runs it in a Rocky 9 container.

## Layout

```
init.lua                entry point; ordered requires, nothing else
lua/config/plugins.lua  runs lua/plugins/*.lua (replaces lazy.nvim)
lua/config/             keymaps, options, autocmds, markdown, export, ...
lua/plugins/            one lazy.nvim-format spec per plugin (shared with Derrekito/nvim)
after/ftplugin/         per-filetype settings
pandoc/                 pandoc filter for :MarkdownExport
queries/, syntax/       treesitter query overrides, pandoc-latex syntax
tests/                  unit + smoke specs (plenary busted)
plugins.lock            pinned plugin commits
install-plugins.sh      installs everything in plugins.lock
```

## Colors

[Rosé Pine Moon](https://rosepinetheme.com), with a local palette override in
`lua/rose-pine-moon.lua`.
