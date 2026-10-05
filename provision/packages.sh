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

# curl comes from curl-minimal, already in every Rocky 9 image; asking for
# the full curl package conflicts with it.
dnf install -y \
  tmux git make gcc gcc-c++ \
  ripgrep fzf tree unzip tar gzip wget \
  python3 python3-pip \
  python-unversioned-command python3-beautifulsoup4 python3-lxml \
  cppcheck clang-tools-extra \
  go-toolset delve \
  bash-completion hostname psmisc procps-ng findutils which \
  libicu

# python-unversioned-command provides `python`, which devdocs.nvim calls; bs4
# and lxml are what its converter (:DevdocsUpdate) needs. libicu: marksman (the
# markdown language server) is a .NET binary that aborts at startup without it.

# Node.js 18+ for the Mason servers and tools written in JS (bashls, jsonls,
# prettier, markdownlint). AppStream's default stream is older.
dnf module reset -y nodejs
dnf module install -y nodejs:22

# Nice to have; git falls back to less when delta isn't installed.
dnf install -y git-delta || echo "note: git-delta not available, skipping"

# Only nvim's :MarkdownExport uses pandoc (EPEL, 2.14), so a repo without it
# (e.g. a company mirror with no EPEL) mustn't stop the install. PDF output
# additionally needs provision/export-tools.sh.
dnf install -y pandoc || echo "note: pandoc not available, skipping (:MarkdownExport won't work)"
