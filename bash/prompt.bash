# Two-line powerline prompt in plain bash: a port of my oh-my-posh "moon"
# theme, with no binary to install. Sourced from bashrc.
#
#   ▐ 🌔 ▶ user@host ▶ …/a/b/c ▶  main +1 ~2 ?3 ⇡1 ▶  venv ▶        ✗ 1  1.2s
#   ❯
#
# Line 1, left: moon phase, # when root, user@host over SSH only, path (last
# three folders), git, Python venv. Right: exit code when nonzero, run time of
# the last command when it took over 500ms. Line 2: ❯, red after a failure.
#
# Settings (environment or local.sh; read at every prompt):
#   PROMPT_THEME=moon|mocha|storm|ember   palette; each tmux-quad pane gets one
#   PROMPT_GLYPHS=nerd|plain              plain: no Nerd Font needed
#   PROMPT_GIT_UNTRACKED=0                skip untracked files (huge repos)
# `prompt_theme <name>` switches palettes in the current shell.

[[ $- == *i* ]] || return 0

# ── Palettes ────────────────────────────────────────────────────────────────
# s0..s3: segment backgrounds, left to right. The rest are foregrounds.
declare -gA _PT=()

prompt_theme() {
  case ${1:-moon} in
    moon) # Rosé Pine Moon
      _PT=([s0]=2a273f [s1]=56526e [s2]=393552 [s3]=44415a
        [glyph]=c4a7e7 [text]=e0def4 [path]=9ccfd8 [lock]=f6c177
        [git_clean]=908caa [git_dirty]=c4a7e7 [git_alert]=eb6f92
        [venv]=3e8fb0 [ok]=3e8fb0 [err]=eb6f92) ;;
    mocha) # Catppuccin Mocha
      _PT=([s0]=313244 [s1]=585b70 [s2]=45475a [s3]=313244
        [glyph]=cba6f7 [text]=cdd6f4 [path]=89dceb [lock]=f9e2af
        [git_clean]=9399b2 [git_dirty]=cba6f7 [git_alert]=f38ba8
        [venv]=a6e3a1 [ok]=a6e3a1 [err]=f38ba8) ;;
    storm) # Tokyo Night Storm
      _PT=([s0]=292e42 [s1]=414868 [s2]=3b4261 [s3]=292e42
        [glyph]=bb9af7 [text]=c0caf5 [path]=7dcfff [lock]=e0af68
        [git_clean]=737aa2 [git_dirty]=bb9af7 [git_alert]=f7768e
        [venv]=9ece6a [ok]=9ece6a [err]=f7768e) ;;
    ember) # warm neutrals, for the fourth pane
      _PT=([s0]=303030 [s1]=4e4e4e [s2]=3a3a3a [s3]=444444
        [glyph]=ffaf5f [text]=d0d0d0 [path]=ffd75f [lock]=ff8700
        [git_clean]=a8a8a8 [git_dirty]=ffaf5f [git_alert]=ff5f5f
        [venv]=87d787 [ok]=87d787 [err]=ff5f5f) ;;
    *)
      echo "prompt_theme: unknown theme '$1' (moon, mocha, storm, ember)" >&2
      return 1 ;;
  esac
  PROMPT_THEME=${1:-moon}
}
prompt_theme "${PROMPT_THEME:-moon}" 2>/dev/null || prompt_theme moon

# ── Building blocks ─────────────────────────────────────────────────────────
# PS1 is just '${_p_line1}...', so the text below is never re-parsed as prompt
# code: a branch named '$(rm -rf ~)' prints as text. Escapes are wrapped in
# \001..\002 (readline's non-printing markers) by hand for the same reason.
_p_esc() { # _p_esc <var> <sgr params>
  printf -v "$1" '\001\e[%sm\002' "$2"
}
_p_rgb() { # _p_rgb <var> rrggbb  ->  var="r;g;b"
  printf -v "$1" '%d;%d;%d' "0x${2:0:2}" "0x${2:2:2}" "0x${2:4:2}"
}

_p_seg() { # _p_seg <bg key> <fg key> <text>: append a powerline segment
  local bg fg; _p_rgb bg "${_PT[$1]}"; _p_rgb fg "${_PT[$2]}"
  local e
  if [[ -z $_p_prev ]]; then
    _p_esc e "0;38;2;$bg"; _p_left+="$e$_p_lead"
  else
    _p_esc e "0;38;2;$_p_prev;48;2;$bg"; _p_left+="$e$_p_sep"
  fi
  (( _p_len += ${#_p_lead} ))  # lead and sep glyphs are one column each
  _p_esc e "48;2;$bg;38;2;$fg"
  _p_left+="$e$3"
  (( _p_len += ${#3} ))
  _p_prev=$bg
}

_p_fg() { # _p_fg <var> <fg key>
  local _p_c; _p_rgb _p_c "${_PT[$2]}"
  _p_esc "$1" "0;38;2;$_p_c"
}

# Nerd Font glyphs, unless PROMPT_GLYPHS=plain or the locale isn't UTF-8
# (bash prints $'\uXXXX' as literal text then, e.g. under LANG=C).
_p_nerd() {
  [[ ${PROMPT_GLYPHS:-nerd} != plain && ${LC_ALL:-${LC_CTYPE:-${LANG:-}}} == *[Uu][Tt][Ff]*8* ]]
}

# ── Git ─────────────────────────────────────────────────────────────────────
# Two git calls per prompt: rev-parse for the git dir (to spot a rebase or
# merge in progress), status --porcelain=v2 for everything else.
_p_git() {
  _p_git_text= _p_git_fg=
  local gitdir
  gitdir=$(GIT_OPTIONAL_LOCKS=0 git rev-parse --git-dir 2>/dev/null) || return
  local ua=(-unormal); [[ ${PROMPT_GIT_UNTRACKED:-1} == 0 ]] && ua=(-uno)
  local out
  out=$(GIT_OPTIONAL_LOCKS=0 git status --porcelain=v2 --branch "${ua[@]}" 2>/dev/null) || return

  local oid= head= ahead=0 behind=0 staged=0 changed=0 untracked=0 conflicts=0 line xy
  while IFS= read -r line; do
    case $line in
      '# branch.oid '*) oid=${line#'# branch.oid '} ;;
      '# branch.head '*) head=${line#'# branch.head '} ;;
      '# branch.ab '*)
        line=${line#'# branch.ab +'}; ahead=${line%% *}; behind=${line##*-} ;;
      [12]' '*)
        xy=${line:2:2}
        [[ ${xy:0:1} != . ]] && (( staged++ ))
        [[ ${xy:1:1} != . ]] && (( changed++ )) ;;
      'u '*) (( conflicts++ )) ;;
      '? '*) (( untracked++ )) ;;
    esac
  done <<<"$out"

  local nerd=0; _p_nerd && nerd=1
  local i_branch=$'\ue725 ' i_commit=$'\uf417 ' i_init=$'\uf0c3 ' i_rebase=$'\ue728 '
  local i_merge=$'\ue727 ' i_pick=$'\ue29b ' i_revert=$'\uf0e2 ' i_conflict=$'\uf071 '
  local i_up=$'\u21e1' i_down=$'\u21e3'
  if (( ! nerd )); then
    i_branch= i_commit=@ i_init='(new) ' i_rebase='REBASE ' i_merge='MERGE '
    i_pick='PICK ' i_revert='REVERT ' i_conflict='!' i_up='^' i_down='v'
  fi

  local busy=
  if [[ -d $gitdir/rebase-merge || -d $gitdir/rebase-apply ]]; then
    local hn= f
    for f in "$gitdir"/rebase-{merge,apply}/head-name; do
      [[ -r $f ]] && { read -r hn <"$f"; break; }
    done
    hn=${hn#refs/heads/}
    head="$i_rebase${hn:-${oid:0:7}}"; busy=1
  elif [[ -f $gitdir/MERGE_HEAD ]]; then head="$i_merge$head"; busy=1
  elif [[ -f $gitdir/CHERRY_PICK_HEAD ]]; then head="$i_pick$head"; busy=1
  elif [[ -f $gitdir/REVERT_HEAD ]]; then head="$i_revert$head"; busy=1
  elif [[ $head == '(detached)' ]]; then head="$i_commit${oid:0:7}"
  elif [[ $oid == '(initial)' ]]; then head="$i_init$head"
  else head="$i_branch$head"
  fi

  local t=" $head"
  (( conflicts )) && t+=" $i_conflict$conflicts"
  (( staged )) && t+=" +$staged"
  (( changed )) && t+=" ~$changed"
  (( untracked )) && t+=" ?$untracked"
  (( ahead )) && t+=" $i_up$ahead"
  (( behind )) && t+=" $i_down$behind"
  _p_git_text="$t "

  if (( conflicts )) || [[ -n $busy ]]; then _p_git_fg=git_alert
  elif (( staged + changed )); then _p_git_fg=git_dirty
  else _p_git_fg=git_clean
  fi
}

# ── Path: ~ for home, then at most the last three folders ───────────────────
_p_path() {
  local p=$PWD
  [[ $p == "$HOME" || $p == "$HOME"/* ]] && p="~${p#"$HOME"}"
  local IFS=/ parts; read -ra parts <<<"$p"
  local n=${#parts[@]}
  if (( n > 4 )); then  # parts[0] is "~" or "" (for /)
    p="…/${parts[n-3]}/${parts[n-2]}/${parts[n-1]}"
  fi
  _p_path_text=$p
}

# ── Command timing ──────────────────────────────────────────────────────────
# A DEBUG trap stamps the start of the first command after each prompt.
# _p_arm runs last in PROMPT_COMMAND, so nothing else in PROMPT_COMMAND (the
# distro's title updater, say) disarms it early and counts idle time at the
# prompt. Skipped if something else already owns the DEBUG trap.
_p_arm() { _p_armed=1; }
_p_preexec() {
  [[ -n $_p_armed ]] || return 0
  _p_armed= _p_ran=1 _p_t0=${EPOCHREALTIME/[.,]/}
}
if [[ -z $(trap -p DEBUG) || $(trap -p DEBUG) == *_p_preexec* ]]; then
  trap '_p_preexec' DEBUG
fi

_p_duration() { # microseconds -> "450ms", "2.3s", "4m 5s", "1h 2m"
  local us=$1 ms=$(( $1 / 1000 ))
  if (( ms < 1000 )); then _p_dur="${ms}ms"
  elif (( ms < 60000 )); then _p_dur="$(( ms / 1000 )).$(( ms % 1000 / 100 ))s"
  elif (( ms < 3600000 )); then _p_dur="$(( ms / 60000 ))m $(( ms % 60000 / 1000 ))s"
  else _p_dur="$(( ms / 3600000 ))h $(( ms % 3600000 / 60000 ))m"
  fi
}

# ── Assemble ────────────────────────────────────────────────────────────────
_p_build() {
  local code=$?
  local nerd=0; _p_nerd && nerd=1
  _p_left= _p_len=0 _p_prev=
  if (( nerd )); then _p_lead=$'\u2590' _p_sep=$'\ue0b0'; else _p_lead=' ' _p_sep=' '; fi

  # Moon phase: the same arithmetic as the oh-my-posh theme, which counts
  # 28 phases per synodic month from a known new moon (2000-01-06 18:14 UTC).
  if (( nerd )); then
    local now=${EPOCHREALTIME%[.,]*}
    local i=$(( (now - 947182440) % 2551443 * 28 / 2551443 % 28 ))
    local hex moon; printf -v hex '%08x' $(( 0xe38d + i )); printf -v moon "\\U$hex"
    _p_seg s0 glyph "$moon "
  else
    _p_seg s0 glyph ""
  fi
  (( EUID == 0 )) && _p_seg s0 err "# "
  [[ -n $SSH_CONNECTION ]] && _p_seg s1 text " ${USER}@${HOSTNAME%%.*} "

  _p_path
  local lock=
  if [[ ! -w $PWD ]]; then
    local c e; _p_rgb c "${_PT[lock]}"; _p_esc e "38;2;$c"
    if (( nerd )); then lock="$e"$'\uf023'" "; else lock="${e}RO "; fi
    (( _p_len -= ${#e} ))  # the escape has no width
  fi
  _p_seg s2 path " $lock$_p_path_text "

  _p_git
  [[ -n $_p_git_text ]] && _p_seg s3 "$_p_git_fg" "$_p_git_text"

  if [[ -n $VIRTUAL_ENV ]]; then
    local venv=${VIRTUAL_ENV##*/}
    if (( nerd )); then _p_seg s0 venv $' \ue73c '"$venv "; else _p_seg s0 venv " py:$venv "; fi
  fi

  # Close the last segment.
  local e r; _p_esc r 0
  _p_esc e "0;38;2;$_p_prev"
  _p_left+="$e$_p_sep$r"; (( _p_len += 1 ))

  # Right side: exit code, run time.
  local right= rlen=0
  if (( code != 0 )); then
    local t; if (( nerd )); then t=$'\uf00d '"$code "; else t="x $code "; fi
    _p_fg e err; right+="$e$t"; (( rlen += ${#t} ))
  fi
  if [[ -n $_p_ran ]]; then
    local dt=$(( ${EPOCHREALTIME/[.,]/} - _p_t0 ))
    if (( dt >= 500000 )); then
      _p_duration "$dt"
      local t; if (( nerd )); then t=$'\U000f051f '"$_p_dur "; else t="$_p_dur "; fi
      if (( code )); then _p_fg e err; else _p_fg e ok; fi
      right+="$e$t"; (( rlen += ${#t} ))
    fi
  fi
  _p_ran=

  # One column spare: a line exactly COLUMNS wide can wrap early in some terminals.
  local pad=$(( ${COLUMNS:-80} - 1 - _p_len - rlen ))
  if [[ -n $right ]] && (( pad >= 1 )); then
    printf -v _p_line1 '%s%*s%s%s' "$_p_left" "$pad" '' "$right" "$r"
  else
    _p_line1=$_p_left
  fi

  local c; if (( code )); then _p_fg c err; else _p_fg c ok; fi
  if (( nerd )); then _p_line2="$c"$'\u276f'"$r "; else _p_line2="$c>$r "; fi

  # Window title outside tmux ("bash in <folder>"). Inside tmux it would
  # clobber the pane titles tmux-quad sets.
  [[ -z $TMUX ]] && printf '\e]0;bash in %s\a' "${PWD##*/}"
}

shopt -s promptvars
PS1='\n${_p_line1}\n${_p_line2}'
PS2='  '
# _p_build runs first, so $? is still the command's exit code; _p_arm last. Guarded against being
# added twice when bashrc is re-sourced.
if [[ ${PROMPT_COMMAND[*]} != *_p_build* ]]; then
  PROMPT_COMMAND="_p_build${PROMPT_COMMAND:+;$PROMPT_COMMAND};_p_arm"
fi
