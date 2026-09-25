#!/usr/bin/env bash
# System packages for Rocky Linux 9. Run as root (Vagrant: privileged: true).
# Safe to re-run.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "run as root: sudo $0" >&2
  exit 1
fi

dnf install -y dnf-plugins-core epel-release
# EPEL expects CodeReady Builder for some of its dependencies.
dnf config-manager --set-enabled crb

dnf install -y \
  neovim tmux git make gcc gcc-c++ \
  ripgrep fzf tree unzip tar gzip curl wget \
  python3 python3-pip \
  cppcheck clang-tools-extra \
  bash-completion hostname psmisc procps-ng findutils which

# Node.js 18+ for the Mason servers and tools written in JS (bashls, jsonls,
# prettier, markdownlint). AppStream's default stream is older.
dnf module reset -y nodejs
dnf module install -y nodejs:22

# Nice to have; git falls back to less when delta isn't installed.
dnf install -y git-delta || echo "note: git-delta not available, skipping"
