#!/bin/sh
cat <<'EOF'
═══════════════════════════════════════════════════════════════════════════════
                            PANE MANAGEMENT HELP
═══════════════════════════════════════════════════════════════════════════════

PANE CREATION:
  |          Split pane horizontally
  -          Split pane vertically
  c          Create new window

PANE NAVIGATION:
  h/C-h      Move to left pane
  j/C-j      Move to pane below
  k/C-k      Move to pane above
  l/C-l      Move to right pane
  ;          Move to last active pane
  o          Move to next pane

PANE RESIZING:
  M-h        Resize pane left
  M-j        Resize pane down
  M-k        Resize pane up
  M-l        Resize pane right

PANE MANAGEMENT:
  x          Kill current pane
  z          Zoom/unzoom current pane
  !          Break pane into new window
  {          Swap with previous pane
  }          Swap with next pane
  H          Swap pane left
  J          Swap pane down
  K          Swap pane up
  L          Swap pane right
  S          Toggle pane synchronization (send input to all panes)

SESSIONS & WINDOWS:
  1..9       Jump to window 1..9 (default tmux)
  0          Jump to window 10
  m          Send current window to another session (fzf)
  w          Show window list (current session, fzf)
  W          Show window list (all sessions, fzf)
  s/a        Show session list (fzf)
  p          Show pane list across all sessions (fzf)
  P          Move current pane into selected window (fzf)
  N          Create new session (prompt for name)
  F          Cheatsheet for the FZF pickers above
  Tab        Switch to last session
  d          Detach from session
  C-h        Move window left
  C-l        Move window right
  r          Reload tmux config

COPY MODE:
  [          Enter copy mode (press H for help there)

OTHER:
  ?          Show this help menu

Press any key to continue...
EOF
read -n 1 _
