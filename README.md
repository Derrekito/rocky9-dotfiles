# rocky9-dotfiles

My development setup for stock Rocky Linux 9: Neovim, tmux, bash, and git,
adjusted for the older versions Rocky 9 ships (Neovim 0.8 from EPEL, tmux
3.2a). It's built to go on a fresh VM with two commands and no GitHub login.

| Directory | What | Installed to |
|-----------|------|--------------|
| `nvim/` | Neovim 0.8 config, plugins pinned in `plugins.lock` ([details](nvim/README.md)) | `~/.config/nvim` (symlink) |
| `tmux/` | tmux 3.2a config, plugins pinned in `plugins.lock`, no TPM ([details](tmux/README.md)) | `~/.config/tmux` (symlink) |
| `bash/bashrc` | env, aliases, vi mode, fzf, tmux and venv helpers | sourced from `~/.bashrc` |
| `bash/inputrc` | readline: vi mode, cursor shape, history prefix search | `~/.inputrc` (symlink) |
| `git/` | shared git settings and aliases, delta colors | `include.path` in `~/.gitconfig` |
| `clang/clang-format` | LLVM style, Allman braces | `~/.clang-format` (symlink) |
| `bin/` | `tmux-attach` | on `PATH` via `bashrc` |

## Install

On the VM:

```bash
sudo dnf install -y git
git clone https://github.com/Derrekito/rocky9-dotfiles ~/rocky9-dotfiles
sudo ~/rocky9-dotfiles/provision/packages.sh   # dnf: EPEL, neovim, tmux, toolchain, node 22
~/rocky9-dotfiles/install.sh                   # links, plugins, parsers
```

`install.sh` is safe to re-run. It moves anything in its way to
`<name>.bak.<timestamp>` rather than deleting it, and it adds lines to
`~/.bashrc` and `~/.gitconfig` instead of replacing them. That way the
distro's (or corp's) settings in those files stay in charge.

To update later: `git -C ~/rocky9-dotfiles pull && ~/rocky9-dotfiles/install.sh`.

### Vagrant

`Vagrantfile` builds a reference VM with both steps as provisioners:
`provision/packages.sh` as root, then `provision/user.sh` (clone + `install.sh`)
as the vagrant user. To use them in another Vagrantfile:

```ruby
config.vm.provision "packages", type: "shell", privileged: true,  path: "provision/packages.sh"
config.vm.provision "dotfiles", type: "shell", privileged: false, path: "provision/user.sh"
```

`DOTFILES_REPO=/vagrant vagrant up` provisions from the synced folder
instead of GitHub, for testing commits before pushing.

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
the main plugin modules, loads `tmux.conf` into a scratch server, and sources
the bash config.
