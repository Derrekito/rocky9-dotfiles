#!/usr/bin/env bash
# Check, before installing, whether this machine's package repos can supply
# what provision/packages.sh (and the optional provision/export-tools.sh)
# install. Meant for EL9 machines whose dnf only sees an internal mirror
# instead of the stock Rocky/RHEL repos plus EPEL: packages may be missing,
# come from a different repo, or be a different version than the plugin pins
# in nvim/plugins.lock assume.
#
#   ./doctor.sh            report; exit 1 if anything packages.sh needs is missing
#   ./doctor.sh --export   also check what export-tools.sh needs
#
# Read-only: runs dnf queries as your user and installs nothing. The package
# lists are read from the provision scripts themselves, so they can't drift.
set -uo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
check_export=0
[ "${1:-}" = "--export" ] && check_export=1

if [ -t 1 ]; then
  red=$'\e[31m' yel=$'\e[33m' grn=$'\e[32m' dim=$'\e[2m' bold=$'\e[1m' off=$'\e[0m'
else
  red='' yel='' grn='' dim='' bold='' off=''
fi
problems=0
ok()   { printf '  %sok%s    %s\n' "$grn" "$off" "$*"; }
warn() { printf '  %swarn%s  %s\n' "$yel" "$off" "$*"; }
bad()  { printf '  %sFAIL%s  %s\n' "$red" "$off" "$*"; problems=$((problems + 1)); }
note() { printf '        %s%s%s\n' "$dim" "$*" "$off"; }
section() { printf '\n%s%s%s\n' "$bold" "$*" "$off"; }

# version_ge A B: is version A >= B (dotted, numeric parts only)?
version_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" = "$2" ]; }

# Package names from every multi-line `dnf install -y \` block in a script.
packages_in() {
  awk '
    /dnf install -y/ { grab = 1 }
    grab {
      line = $0; sub(/#.*/, "", line); sub(/\|\|.*/, "", line)
      n = split(line, w, /[ \t\\]+/)
      for (i = 1; i <= n; i++)
        if (w[i] != "" && w[i] !~ /^-/ && w[i] != "dnf" && w[i] != "install" && w[i] !~ /[|&;]/) print w[i]
      if ($0 !~ /\\[ \t]*$/) grab = 0
    }' "$1" | sort -u
}

# ---------------------------------------------------------------------------
section "System"
. /etc/os-release 2>/dev/null
echo "  ${PRETTY_NAME:-unknown OS} ($(uname -m))"
case "${ID:-}:${VERSION_ID:-}" in
  rocky:9*|rhel:9*|almalinux:9*|centos:9*|ol:9*) ;;
  *) warn "this repo targets EL9 (Rocky/RHEL 9); this is ${ID:-?} ${VERSION_ID:-?}" ;;
esac
if sudo -n true 2>/dev/null; then
  ok "passwordless sudo (packages.sh runs as root)"
else
  note "packages.sh needs root: run it with sudo (or have it run for you)"
fi

# ---------------------------------------------------------------------------
section "Enabled repos"
repolist=$(dnf -q repolist --enabled 2>&1)
if [ $? -ne 0 ] || [ -z "$repolist" ]; then
  bad "dnf repolist failed or found no enabled repos"
  echo "$repolist" | sed 's/^/        /'
  exit 1
fi
echo "$repolist" | sed 's/^/  /'
# Where each enabled repo actually points (internal mirror vs upstream).
hosts=$(dnf -q repoinfo --enabled 2>/dev/null | awk '/^Repo-baseurl|^Repo-mirrors|^Repo-metalink/ { sub(/^[^:]*: */, ""); print }' |
  grep -o -E '(https?|file)://[^/ ]+' | sort -u)
[ -n "$hosts" ] && { echo "  served from:"; echo "$hosts" | sed 's/^/    /'; }

has_repo() { grep -q -i -E "$1" <<<"$repolist"; }
if has_repo '^epel|[^a-z]epel'; then ok "an EPEL repo is enabled"
else warn "no repo named like EPEL: packages.sh installs epel-release and gets ripgrep, fzf, cppcheck, pandoc, chromium from it"; fi
if has_repo 'crb|codeready'; then ok "CodeReady Builder (crb) is enabled"
else warn "no CRB/CodeReady repo: packages.sh runs 'dnf config-manager --set-enabled crb', which fails if no such repo exists"; fi

# ---------------------------------------------------------------------------
# One repoquery for every name: "name version repoid", newest per name.
declare -A avail_ver avail_repo
query() {
  local out
  out=$(dnf -q repoquery --available --latest-limit 1 --qf '%{name} %{version} %{repoid}' "$@" 2>/dev/null)
  while read -r n v r; do
    [ -n "$n" ] || continue
    avail_ver[$n]=$v
    avail_repo[$n]=$r
  done <<<"$out"
}

check_list() { # check_list <label> <names...>
  local label=$1; shift
  query "$@"
  local missing=()
  for p in "$@"; do
    if rpm -q "$p" >/dev/null 2>&1; then
      ok "$p $(rpm -q --qf '%{VERSION}' "$p" 2>/dev/null | head -1) ${dim}(installed)${off}"
    elif [ -n "${avail_ver[$p]:-}" ]; then
      ok "$p ${avail_ver[$p]} ${dim}from ${avail_repo[$p]}${off}"
    else
      missing+=("$p")
    fi
  done
  for p in "${missing[@]}"; do
    case "$p" in
      git-delta) warn "$p: not available (optional; packages.sh skips it)" ;;
      pandoc) warn "$p: not available (optional; packages.sh skips it, and nvim's :MarkdownExport won't work)" ;;
      *) bad "$p: not available from any enabled repo ($label)" ;;
    esac
  done
}

section "packages.sh"
mapfile -t base < <(packages_in "$repo/provision/packages.sh")
check_list "packages.sh" "${base[@]}"

# Versions the pinned config is built around (installed, else available).
installed_ver() { rpm -q "$1" >/dev/null 2>&1 && rpm -q --qf '%{VERSION}' "$1" | head -1; }
tv=$(installed_ver tmux); tv=${tv:-${avail_ver[tmux]:-}}
[ -n "$tv" ] && [ "$tv" != "3.2a" ] && warn "tmux $tv: tmux.conf targets 3.2a; check tmux/README.md if options error"

# ---------------------------------------------------------------------------
section "vendor/ (Neovim, tree-sitter, hunk, nvim and tmux plugins: install.sh never downloads them)"
# x86_64 release builds, copied in by hand; see vendor/README.md.
if [ "$(uname -m)" = x86_64 ]; then
  ok "x86_64, matching the builds vendor/ holds"
else
  bad "$(uname -m): vendor/ holds x86_64 builds"
fi
while read -r name version file sha _; do
  f="$repo/vendor/$file"
  if [ ! -f "$f" ]; then
    bad "vendor/$file missing ($name $version): rsync it in, or run provision/fetch-vendor.sh elsewhere"
  elif echo "$sha  $f" | sha256sum -c --quiet >/dev/null 2>&1; then
    ok "vendor/$file ($name $version)"
  else
    bad "vendor/$file doesn't match its sha256 in vendor/MANIFEST (not $name $version?)"
  fi
done < <(grep -v '^[[:space:]]*\(#\|$\)' "$repo/vendor/MANIFEST")
# Plugin archives: vendor/<set>.tar.gz, each plugin at the commit its lock
# pins (<set>/COMMITS inside lists them).
check_plugins() { # check_plugins LOCK SET
  local lock="$1" set="$2" archive="$repo/vendor/$2.tar.gz" commits name sha have total
  local missing=() stale=()
  total=$(grep -c -v '^[[:space:]]*\(#\|$\)' "$lock")
  if [ ! -f "$archive" ]; then
    bad "vendor/$set.tar.gz missing ($total plugins): rsync it in, or run provision/fetch-vendor.sh elsewhere"
    return
  fi
  commits="$(tar -xzOf "$archive" "$set/COMMITS" 2>/dev/null)"
  while read -r name _ sha _; do
    case "$name" in '' | '#'*) continue ;; esac
    have="$(awk -v n="$name" '$1 == n { print $2 }' <<<"$commits")"
    if [ -z "$have" ]; then missing+=("$name")
    elif [ "$have" != "$sha" ]; then stale+=("$name"); fi
  done <"$lock"
  if [ ${#missing[@]} -eq 0 ] && [ ${#stale[@]} -eq 0 ]; then
    ok "vendor/$set.tar.gz: all $total plugins at their pinned commits"
  else
    [ ${#missing[@]} -gt 0 ] && bad "vendor/$set.tar.gz lacks ${#missing[@]} of $total: ${missing[*]}"
    [ ${#stale[@]} -gt 0 ] && bad "vendor/$set.tar.gz not at the pinned commit: ${stale[*]} (re-run provision/fetch-vendor.sh)"
  fi
}
check_plugins "$repo/nvim/plugins.lock" nvim-plugins
check_plugins "$repo/tmux/plugins.lock" tmux-plugins
glibc=$(ldd --version 2>/dev/null | head -1 | grep -o -E '[0-9]+\.[0-9]+$')
if [ -n "$glibc" ] && version_ge "$glibc" 2.34; then
  ok "glibc $glibc: the pinned tree-sitter 0.25.10 runs on 2.34+ (0.26+ would need 2.35)"
elif [ -n "$glibc" ]; then
  bad "glibc $glibc: older than EL9's 2.34; the pinned tree-sitter CLI won't run"
fi
if rpm -q neovim >/dev/null 2>&1; then
  note "EPEL's neovim $(installed_ver neovim) is also installed; ~/.local/bin/nvim comes first on PATH"
fi

# ---------------------------------------------------------------------------
section "Node.js (packages.sh enables the nodejs:22 module stream)"
streams=$(dnf -q module list nodejs 2>/dev/null | awk '$1 == "nodejs" {print $2}' | sort -uV | tr '\n' ' ')
if [ -z "$streams" ]; then
  nodever=${avail_ver[nodejs]:-}
  [ -z "$nodever" ] && query nodejs && nodever=${avail_ver[nodejs]:-}
  if [ -n "$nodever" ]; then
    warn "no nodejs module streams; plain nodejs $nodever is available. 'dnf module install nodejs:22' will fail"
    version_ge "$nodever" 18 || bad "nodejs $nodever: Mason's JS servers (bashls, jsonls, markdownlint) need 18+"
  else
    bad "no nodejs at all: Mason's JS servers and tools (bashls, jsonls, prettier, markdownlint) need Node 18+"
  fi
elif grep -qw 22 <<<"$streams"; then
  ok "nodejs streams: $streams"
else
  bad "nodejs streams available: $streams- no 22, which packages.sh asks for (18+ works for Mason; mermaid-cli needs 22.13+)"
fi

# ---------------------------------------------------------------------------
if [ $check_export -eq 1 ]; then
  section "export-tools.sh (optional: PDF export, mermaid diagrams)"
  mapfile -t extra < <(packages_in "$repo/provision/export-tools.sh")
  check_list "export-tools.sh" "${extra[@]}"
fi

# ---------------------------------------------------------------------------
section "Not from dnf"
note "install.sh and Neovim also fetch from GitHub (plugins, treesitter parsers, Mason's"
note "registry and servers, hunk) and npm (Mason's JS tools, mermaid-cli); those go"
note "through your proxy, not the dnf repos."
git_proxy=$(git config --get http.proxy 2>/dev/null)
env_proxy=${https_proxy:-${HTTPS_PROXY:-}}
echo "  proxy: env=${env_proxy:-none}  git=${git_proxy:-none}"
command -v npm >/dev/null && echo "  npm registry: $(npm config get registry 2>/dev/null)"
pipidx=$(python3 -m pip config list 2>/dev/null | grep -i index-url | head -1)
[ -n "$pipidx" ] && echo "  pip: $pipidx"

# ---------------------------------------------------------------------------
echo
if [ $problems -eq 0 ]; then
  echo "${grn}No blockers found.${off}"
else
  echo "${red}$problems problem(s).${off} packages.sh (or export-tools.sh) stops at the first missing package; install.sh at the first missing vendor/ file."
  echo "Missing packages need another source: ask for them on the mirror, or install them outside dnf."
  has_repo '^epel|[^a-z]epel' ||
    echo "On stock Rocky/RHEL 9, ripgrep, fzf, cppcheck and python3-beautifulsoup4 (and the optional pandoc) come from EPEL; a mirror of EPEL 9 would cover them."
fi
exit $(( problems > 0 ))
