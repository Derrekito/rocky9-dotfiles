#!/bin/sh
cat <<'EOF'
═══════════════════════════════════════════════════════════════════════════════
                      SESSION/WINDOW CHOOSER HELP
═══════════════════════════════════════════════════════════════════════════════

NAVIGATION:
  j/Down     Move down one item
  k/Up       Move up one item
  Enter      Select/switch to highlighted session/window
  q/Escape   Exit chooser

SESSION MANAGEMENT:
  d          Kill selected session
  x          Kill selected session
  D          Kill selected session (prompt)

WINDOW MANAGEMENT:
  &          Kill selected window
  X          Kill selected window (prompt)

FILTERING & SEARCH:
  s          Search/filter items
  /          Search forward
  n          Next match
  N          Previous match

VIEW OPTIONS:
  v          Toggle preview
  t          Toggle tree/flat view
  O          Change sort order

OTHER:
  ?          Show built-in tmux help
  h/F1       Show this help menu

Press any key to continue...
EOF
read -n 1 _
