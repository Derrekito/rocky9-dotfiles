#!/bin/sh
cat <<'EOF'
═══════════════════════════════════════════════════════════════════════════════
                              COPY MODE HELP
═══════════════════════════════════════════════════════════════════════════════

MOVEMENT:
  h/Left     Move cursor left
  j/Down     Move cursor down
  k/Up       Move cursor up
  l/Right    Move cursor right
  w          Jump to next word
  b          Jump to previous word
  0/^        Jump to start of line
  $          Jump to end of line
  g          Jump to top of buffer
  G          Jump to bottom of buffer

SELECTION:
  v          Start selection
  V          Select whole line
  C-v        Rectangle selection
  y          Copy selection and exit
  Enter      Copy selection and exit

SEARCH:
  /          Search forward (case-insensitive)
  ?          Search backward (case-insensitive)
  n          Next search result
  N          Previous search result

OTHER:
  q/Escape   Exit copy mode
  H          Show this help menu

Press any key to continue...
EOF
read -n 1 _
