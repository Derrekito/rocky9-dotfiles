#!/bin/sh
cat <<'EOF'
═══════════════════════════════════════════════════════════════════════════════
                          FZF PICKERS — CHEATSHEET
═══════════════════════════════════════════════════════════════════════════════

PICKERS (all open via prefix C-Space then the key below):

  m     Send current window to session   (excludes current session)
  w     Windows in current session       [preview enabled]
  W     All sessions (window tree preview)
  s     Sessions                         (a does the same)
  a     Sessions                         (alias of s)
  p     All panes across sessions        [preview enabled]
  P     Move current pane into a window  [preview enabled]
  N     New session (prompts for name)
  F     Show this help

INSIDE THE FZF POPUP:

  Type        Fuzzy-filter the list
  Up/Down     Move selection (also C-p / C-n)
  Enter       Select / switch to highlighted item
  Esc / C-c   Cancel and close popup
  C-u / C-w   Clear query / delete word
  Tab         Move selection down (no multi-select here)

PREVIEW PANE (where available):

  Shows a live capture of the target pane on the right.
  Updates as you move the selection.

TIPS:

  - The query is fuzzy: typing "snd" matches "session-name-dev".
  - For sessions: 's' and 'a' are identical — use whichever is comfier.
  - 'W' pre-selects your current window so Enter is a no-op exit.

Press any key to continue...
EOF
read -n 1 _
