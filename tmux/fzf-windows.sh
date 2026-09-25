#!/bin/bash
current="$1"
# Put current window first so it's highlighted by default
{
    tmux list-windows -a -F "#{session_name}:#{window_index} │ #{window_name} #{?window_active,(active),}" | grep "^$current "
    tmux list-windows -a -F "#{session_name}:#{window_index} │ #{window_name} #{?window_active,(active),}" | grep -v "^$current "
} | \
fzf --reverse --header="Switch window (all sessions) — prefix F for help" \
    --preview="tmux capture-pane -ep -t {1}" \
    --preview-window=right:50% \
    --color="bg+:#3e8fb0,fg+:#e0def4,hl:#c4a7e7,hl+:#c4a7e7,header:#9ccfd8,pointer:#eb6f92" | \
cut -d" " -f1 | \
xargs -r tmux switch-client -t
