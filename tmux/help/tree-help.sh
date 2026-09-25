#!/bin/sh
cat <<'EOF'
═══════════════════════════════════════════════════════════════════
              SESSION/WINDOW TREE HELP
═══════════════════════════════════════════════════════════════════

First press <leader>+w to open tree, then use:

NAVIGATION:
  j/k/↑/↓    Move up/down
  Enter      Switch to selection
  q/Escape   Exit tree

SESSION OPERATIONS:
  d          Kill session
  $          Rename session

WINDOW OPERATIONS:
  &          Kill window
  ,          Rename window

SEARCH:
  s          Search/filter

Press any key to continue...
EOF
read -n 1 _
