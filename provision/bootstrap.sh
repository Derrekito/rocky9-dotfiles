#!/usr/bin/env bash
# One-call setup for a Rocky Linux 9 VM, run as root (e.g. from a Vagrant
# provision.sh, which runs as root by default):
#
#   bootstrap.sh [user]        default user: $SUDO_USER, else vagrant
#
# 1. installs git
# 2. clones (or updates) this repo into ~user/rocky9-dotfiles, as that user
# 3. installs system packages (provision/packages.sh)
# 4. runs install.sh as that user
#
# Safe to re-run. Environment:
#   DOTFILES_REPO   clone source (default: GitHub; a local path works too)
#   DOTFILES_REF    branch or tag to check out (default: the repo's default)
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "run as root: sudo $0 [user]" >&2
  exit 1
fi

user="${1:-${SUDO_USER:-vagrant}}"
home="$(getent passwd "$user" | cut -d: -f6)" ||
  { echo "bootstrap: no such user: $user" >&2; exit 1; }
repo="${DOTFILES_REPO:-https://github.com/Derrekito/rocky9-dotfiles.git}"
dir="$home/rocky9-dotfiles"

as_user() { sudo -u "$user" -H -- "$@"; }

echo "==> git"
command -v git >/dev/null || dnf install -y git

echo "==> rocky9-dotfiles -> $dir"
if [ -d "$dir/.git" ]; then
  as_user git -C "$dir" pull --ff-only
else
  as_user git clone ${DOTFILES_REF:+--branch "$DOTFILES_REF"} "$repo" "$dir"
fi

echo "==> packages"
"$dir/provision/packages.sh"

echo "==> install.sh as $user"
# A login shell, so PATH and HOME are the user's own.
sudo -iu "$user" -- "$dir/install.sh"
