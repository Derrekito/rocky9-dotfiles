#!/usr/bin/env bash
# Optional extras for Neovim's :MarkdownExport: PDF documents and slides
# (TeX Live 2020 + latexmk, LuaLaTeX) and mermaid diagrams in exports
# (mermaid-cli on EPEL's headless Chromium). DOCX export only needs pandoc,
# which packages.sh installs. Several hundred MB, so not part of packages.sh.
#
#   sudo ~/rocky9-dotfiles/provision/export-tools.sh
#
# Safe to re-run.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "run as root: sudo $0" >&2
  exit 1
fi

MERMAID_CLI_VERSION=12.0.0   # needs Node >= 22.13 (packages.sh installs nodejs:22)

# What pandoc's LaTeX and Beamer templates load under LuaLaTeX, plus the
# packages they use when present (upquote, microtype, parskip, bookmark).
# framed: pandoc 2.x wraps highlighted code in it. ctablestack: LuaLaTeX
# needs it for pandoc 2.x's template on TeX Live 2020.
dnf install -y \
  latexmk texlive-scheme-basic texlive-collection-latexrecommended \
  texlive-luatex texlive-luaotfload texlive-fontspec texlive-unicode-math \
  texlive-lualatex-math texlive-lm texlive-lm-math texlive-selnolig \
  texlive-beamer texlive-pgf texlive-xcolor texlive-booktabs texlive-caption \
  texlive-fancyvrb texlive-upquote texlive-microtype texlive-parskip \
  texlive-bookmark texlive-hyperref texlive-iftex texlive-etoolbox \
  texlive-geometry texlive-amsmath texlive-tools texlive-babel-english \
  texlive-framed texlive-ctablestack \
  chromium-headless

# mermaid-cli, pointed at EPEL's Chromium instead of letting puppeteer
# download its own (which, from a root npm -g, would land in root's home).
PUPPETEER_SKIP_DOWNLOAD=1 npm install -g "@mermaid-js/mermaid-cli@$MERMAID_CLI_VERSION"

chrome=/usr/lib64/chromium-browser/headless_shell
args='[]'
# Chromium's sandbox needs user namespaces, which containers usually lack.
# On a VM it works, so only containers get --no-sandbox.
if [ -f /.dockerenv ] || [ -f /run/.containerenv ]; then
  args='["--no-sandbox"]'
fi
mkdir -p /etc/mermaid
cat > /etc/mermaid/puppeteer.json <<EOF
{ "executablePath": "$chrome", "args": $args }
EOF
echo "mermaid-cli $MERMAID_CLI_VERSION using $chrome (puppeteer config: /etc/mermaid/puppeteer.json)"
