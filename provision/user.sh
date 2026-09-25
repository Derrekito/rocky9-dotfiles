#!/usr/bin/env bash
# Clone (or update) this repo and run install.sh. Run as the login user
# (Vagrant: privileged: false).
#
#   DOTFILES_REPO  where to clone from (default: GitHub)
#   DOTFILES_DIR   where to put it     (default: ~/rocky9-dotfiles)
set -euo pipefail

repo="${DOTFILES_REPO:-https://github.com/Derrekito/rocky9-dotfiles.git}"
dir="${DOTFILES_DIR:-$HOME/rocky9-dotfiles}"

if [ -d "$dir/.git" ]; then
  git -C "$dir" pull --ff-only
else
  git clone "$repo" "$dir"
fi
"$dir/install.sh"
