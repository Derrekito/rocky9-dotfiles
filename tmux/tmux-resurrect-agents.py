#!/usr/bin/env python3
"""tmux-resurrect post-save-layout hook.

Rewrites the saved command of every pane running an AI agent so that a
restore resumes that pane's exact conversation instead of starting fresh
(or grabbing whichever conversation in the directory was most recent).
Pair with `set -g @resurrect-processes ':all:'`, which replays each pane's
saved command.

Also refuses saves taken during system shutdown (agents may already be dead)
and empty saves (tmux already dying): the file is overwritten with the previous
good save, and resurrect then discards it as a duplicate instead of moving
`last`.
"""
import json
import os
import shlex
import shutil
import sqlite3
import subprocess
import sys

HOME = os.path.expanduser("~")
AGENTS = ("claude", "codex", "grok", "agy", "opencode")

# Args that select a conversation; stripped from the saved command before the
# exact resume args are appended. Value is True when the flag takes a value.
SESSION_FLAGS = {
    "claude": {"--continue": False, "-c": False, "--resume": True, "-r": True},
    "codex": {},  # handled by subcommand stripping below
    "grok": {"--continue": False, "-c": False, "--resume": True, "-r": True},
    "agy": {"--continue": False, "-c": False, "--conversation": True},
    "opencode": {"--continue": False, "-c": False, "--session": True, "-s": True},
}
# When no exact ID is found. claude --continue is scoped to the cwd;
# the others' "continue" is global and would grab an unrelated conversation,
# so they start fresh (usually the pane never had a conversation).
FALLBACK = {
    "claude": ["--continue"],
    "codex": [],
    "grok": [],
    "agy": [],
    "opencode": [],
}


def live_panes():
    fmt = "#{session_name}\t#{window_index}\t#{pane_index}\t#{pane_pid}"
    out = subprocess.run(["tmux", "list-panes", "-a", "-F", fmt],
                         capture_output=True, text=True).stdout
    panes = {}
    for line in out.splitlines():
        s, w, p, pid = line.split("\t")
        panes[(s, w, p)] = int(pid)
    return panes


def agent_process(pane_pid):
    """Return (agent_name, pid) for an agent that is a direct child of the pane shell."""
    try:
        kids = subprocess.run(["pgrep", "-P", str(pane_pid)],
                              capture_output=True, text=True).stdout.split()
    except OSError:
        return None
    for k in kids:
        try:
            comm = open(f"/proc/{k}/comm").read().strip()
        except OSError:
            continue
        if comm in AGENTS:
            return comm, int(k)
    return None


def claude_id(pid, **_):
    try:
        return json.load(open(f"{HOME}/.claude/sessions/{pid}.json"))["sessionId"]
    except (OSError, ValueError, KeyError):
        return None


def grok_id(pid, **_):
    try:
        for s in json.load(open(f"{HOME}/.grok/active_sessions.json")):
            if s.get("pid") == pid:
                return s["session_id"]
    except (OSError, ValueError):
        pass
    return None


def agy_id(pid, **_):
    # agy holds presence/<conversation-id>.lock open for its conversation.
    try:
        for fd in os.listdir(f"/proc/{pid}/fd"):
            target = os.readlink(f"/proc/{pid}/fd/{fd}")
            if "/antigravity-cli/presence/" in target and target.endswith(".lock"):
                return os.path.basename(target)[:-5]
    except OSError:
        pass
    return None


def codex_id(cwd, title, claimed, **_):
    # The TUI is a client of a shared daemon, so no per-pid record exists.
    # It titles the pane "<thread name> | <dir>": match that name first, then
    # fall back to the most recent unclaimed thread in the pane's directory.
    try:
        db = sqlite3.connect(f"file:{HOME}/.codex/state_5.sqlite?mode=ro", uri=True)
        rows = db.execute(
            "select id, coalesce(name, title) from threads where cwd = ? and archived = 0 "
            "and agent_role is null order by updated_at_ms desc",
            (cwd,)).fetchall()
    except sqlite3.Error:
        return None
    name = title.rsplit(" | ", 1)[0] if " | " in title else None
    for tid, tname in rows:
        if name and tname == name and tid not in claimed:
            return tid
    for tid, _ in rows:
        if tid not in claimed:
            return tid
    return None


def opencode_id(cwd, claimed, **_):
    # No per-pid record either; most recent unclaimed top-level session in cwd.
    try:
        db = sqlite3.connect(f"file:{HOME}/.local/share/opencode/opencode.db?mode=ro", uri=True)
        rows = db.execute(
            "select id from session where directory = ? and parent_id is null "
            "order by time_updated desc", (cwd,)).fetchall()
    except sqlite3.Error:
        return None
    for (sid,) in rows:
        if sid not in claimed:
            return sid
    return None


RESOLVERS = {"claude": claude_id, "grok": grok_id, "agy": agy_id,
             "codex": codex_id, "opencode": opencode_id}


def resume_args(agent, sid):
    if sid is None:
        return FALLBACK[agent]
    return {
        "claude": ["--resume", sid],
        "codex": ["resume", sid],
        "grok": ["--resume", sid],
        "agy": ["--conversation", sid],
        "opencode": ["--session", sid],
    }[agent]


def strip_session_args(agent, argv):
    """Keep the user's other flags (model, permissions...) but drop session selection."""
    rest = argv[1:]
    if agent == "codex":
        if rest and rest[0] == "resume":
            rest = rest[1:]
            if rest and not rest[0].startswith("-"):
                rest = rest[1:]  # thread id
            rest = [a for a in rest if a not in ("--last", "--all")]
        return rest
    flags = SESSION_FLAGS[agent]
    out, skip = [], False
    for a in rest:
        if skip:
            skip = False
            if not a.startswith("-"):
                continue
        key = a.split("=", 1)[0]
        if key in flags:
            skip = flags[key] and "=" not in a
            continue
        out.append(a)
    return out


def main(path):
    with open(path) as f:
        lines = f.read().splitlines()

    # During shutdown, agents can die before tmux does; such a save still has
    # panes but no agents and would clobber the good one. Discard it too.
    stopping = subprocess.run(["systemctl", "is-system-running"],
                              capture_output=True, text=True).stdout.strip() == "stopping"
    if stopping or not any(l.startswith("pane\t") for l in lines):
        last = os.path.join(os.path.dirname(path), "last")
        if os.path.exists(last):
            shutil.copyfile(last, path)
        return

    panes = live_panes()
    claimed = {"codex": set(), "opencode": set()}
    for i, line in enumerate(lines):
        f = line.split("\t")
        if f[0] != "pane" or len(f) < 11:
            continue
        pane_pid = panes.get((f[1], f[2], f[5]))
        hit = pane_pid and agent_process(pane_pid)
        if not hit:
            continue
        agent, pid = hit
        cwd, title = f[7].lstrip(":"), f[6]
        sid = RESOLVERS[agent](pid=pid, cwd=cwd, title=title,
                               claimed=claimed.get(agent, set()))
        if sid and agent in claimed:
            claimed[agent].add(sid)
        try:
            argv = open(f"/proc/{pid}/cmdline").read().split("\0")[:-1]
        except OSError:
            argv = [agent]
        argv = [agent] + strip_session_args(agent, argv) + resume_args(agent, sid)
        f[10] = ":" + shlex.join(argv)
        lines[i] = "\t".join(f)

    with open(path, "w") as out:
        out.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main(sys.argv[1])
