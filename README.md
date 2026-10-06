# rocky9-dotfiles

My development setup for stock Rocky Linux 9: Neovim, tmux, bash, and git.
Neovim is the current release build (installed in your home directory, not
EPEL's 0.8) running the same config as my main machines; tmux and the rest are
adjusted for what Rocky 9 ships (tmux 3.2a). It's built to go on a fresh VM with
two commands and no GitHub login.

| Directory | What | Installed to |
|-----------|------|--------------|
| `nvim/` | Neovim 0.12 config, plugins pinned in `plugins.lock`, no plugin manager ([details](nvim/README.md)) | `~/.config/nvim` (symlink) |
| `tmux/` | tmux 3.2a config, plugins pinned in `plugins.lock`, no TPM ([details](tmux/README.md)) | `~/.config/tmux` (symlink) |
| `bash/bashrc` | env, aliases, vi mode, fzf, tmux and venv helpers | sourced from `~/.bashrc` |
| `bash/prompt.bash` | two-line powerline prompt with git status, in plain bash | sourced by `bashrc` |
| `bash/inputrc` | readline: vi mode, cursor shape, history prefix search | `~/.inputrc` (symlink) |
| `git/` | shared git settings and aliases, delta colors | `include.path` in `~/.gitconfig` |
| `clang/clang-format` | LLVM style, Allman braces | `~/.clang-format` (symlink) |
| `hunk/config.toml` | Rosé Pine Moon theme for [hunk](https://github.com/modem-dev/hunk) | `~/.config/hunk/config.toml` (symlink) |
| `bin/` | `tmux-attach`, `tmux-quad` | on `PATH` via `bashrc` |
| `texmf/` | RosePineMoon Beamer theme parts, for nvim's `:MarkdownExport slides` | `~/texmf/tex/latex/beamer/RosePineMoon/` (one symlink per file) |

`install.sh` also installs three release binaries into `~/.local/bin`: Neovim
0.12.5, the tree-sitter CLI (0.25.10, which builds Neovim's parsers), and
[hunk](https://github.com/modem-dev/hunk). It doesn't download them. They come
from `vendor/`, which git doesn't track: you copy the files in, and
`install.sh` checks each against the SHA256 in `vendor/MANIFEST`
([details](vendor/README.md)).

## Install

On the VM:

```bash
sudo dnf install -y git
git clone https://github.com/Derrekito/rocky9-dotfiles ~/rocky9-dotfiles
sudo ~/rocky9-dotfiles/provision/packages.sh   # dnf: EPEL, tmux, toolchain, node 22
```

Copy the release files into `vendor/`. From a machine that has them (or after
running `provision/fetch-vendor.sh` there to download them):

```bash
rsync -av ~/rocky9-dotfiles/vendor/ vm:rocky9-dotfiles/vendor/
```

Then, on the VM:

```bash
~/rocky9-dotfiles/install.sh                   # links, Neovim, plugins, parsers
```

Optional: `sudo ~/rocky9-dotfiles/provision/export-tools.sh` adds TeX Live and
mermaid-cli, so Neovim's `:MarkdownExport` can make PDFs and draw diagrams
(DOCX works without it). Several hundred MB, so it isn't part of the default
install.

`install.sh` is safe to re-run. It moves anything in its way to
`<name>.bak.<timestamp>` rather than deleting it, and it adds lines to
`~/.bashrc` and `~/.gitconfig` instead of replacing them. That way the
distro's (or corp's) settings in those files stay in charge.

To update later: `git -C ~/rocky9-dotfiles pull && ~/rocky9-dotfiles/install.sh`.

### Machines with an internal package mirror

`packages.sh` assumes the stock Rocky repos plus EPEL and CodeReady Builder.
A work machine whose dnf only sees a company mirror may lack some of those
packages, have them under other repo names, or carry different versions. Run
`./doctor.sh` first (no root needed, installs nothing): it lists the enabled
repos and where they're served from, then checks every package `packages.sh`
installs (`--export` adds `export-tools.sh`'s) and the tmux and Node
versions the pinned config assumes. It exits non-zero if something
`packages.sh` needs isn't available, so you know before the install stops
halfway.

### Vagrant (or any root provisioning script)

`provision/bootstrap.sh <user>` does the whole thing in one call, as root:
installs git, clones this repo into `~<user>/rocky9-dotfiles` as that user,
runs `packages.sh`, then runs `install.sh` as the user. Re-running it updates
everything. When `DOTFILES_REPO` is a local checkout (Vagrant's synced folder),
its `vendor/` files are copied into the clone. Cloning from GitHub brings no
`vendor/` files, so copy them in before `install.sh` runs. From a
`provision.sh`:

```bash
curl -fsSL https://raw.githubusercontent.com/Derrekito/rocky9-dotfiles/main/provision/bootstrap.sh | bash -s -- vagrant
```

Or, without piping to bash:

```bash
dnf install -y git
sudo -u vagrant git clone https://github.com/Derrekito/rocky9-dotfiles ~vagrant/rocky9-dotfiles
~vagrant/rocky9-dotfiles/provision/bootstrap.sh vagrant
```

The `Vagrantfile` here builds a reference VM the same way.

`DOTFILES_REPO=/vagrant vagrant up` provisions from the synced folder
instead of GitHub, for testing commits before pushing.

## Prompt

`bash/prompt.bash` is a port of my oh-my-posh "moon" theme to plain bash, so
there's nothing to install or get approved. It has two lines. The first shows
the moon phase, `#` when root, `user@host` over SSH only, the path, git, and
the Python venv. At the right edge it shows the exit code when nonzero and
the run time when over 500ms. The second line is `❯`, red after a failure.

The git segment shows the branch (or short SHA when detached), any rebase,
merge, cherry-pick or revert in progress, and counts: conflicts, `+`staged,
`~`modified, `?`untracked, `⇡`ahead, `⇣`behind. Its color is muted when
clean, iris when dirty, and red on conflicts or mid-operation. It costs two
`git` calls per prompt. In a huge repo, `PROMPT_GIT_UNTRACKED=0` skips the
untracked scan.

Settings, in `local.sh` or the environment:

- `PROMPT_THEME`: `moon` (default), `mocha`, `storm` or `ember`. Or run
  `prompt_theme <name>` to switch the current shell.
- `PROMPT_GLYPHS=plain`: no Nerd Font icons. This is automatic when the
  locale isn't UTF-8.

`tmux-quad [name]` opens a 2x2 window next to the current one. Each pane gets
its own prompt theme, background tint, and colored label on its border, so
the panes are easy to tell apart in a demo.

## What stays out of this repo

Nothing machine-specific or private is committed. Instead:

- **Shell:** `~/.config/rocky9-dotfiles/local.sh` is sourced last by
  `bashrc` (created empty by `install.sh`). Work aliases, proxies, and the
  `DOTFILES_TMUX_ON_SSH=0` switch go there.
- **Git identity, credentials, proxy:** keep them in `~/.gitconfig` itself.
  `git/gitconfig` has no `[user]` or `[credential]` section on purpose.

## Keeping secrets out

- `hooks/pre-commit` runs gitleaks on staged changes, or a basic grep when
  gitleaks isn't installed. It also refuses commits whose author email isn't
  a GitHub noreply address. Turn it on once per clone:
  `git config core.hooksPath hooks`.
- `.gitleaks.toml` adds two rules to gitleaks' defaults: absolute
  `/home/<user>/` paths and personal email addresses.
- CI runs gitleaks over the full history on every push.

## CI

`.github/workflows/ci.yml` runs `packages.sh` and `install.sh` (twice, to
check it's idempotent) in a `rockylinux:9` container, then `test/smoke.sh`.
The smoke test starts nvim headless and fails on any startup error, requires
the main plugin modules, runs the markdown checks and Neovim's own test suite
(`nvim/tests`), loads `tmux.conf` into a scratch server, and sources the bash
config.
