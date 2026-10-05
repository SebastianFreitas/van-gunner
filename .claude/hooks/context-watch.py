"""Context watch: keeps every context small, because quality drops as a
context grows, long before the window is full.

Main session (PreToolUse, UserPromptSubmit): warns from 90% of its line
and says to finish and hand off past it (rules in .claude/rules/
workflow.md "Context budget"; handoff format in .claude/skills/handoff).
The line depends on the window:
- a headless plan session: AUTOPLAN_LINE from tools/autoplan.py;
- a prepared run (a go prompt naming .claude/handoff.md while it starts
  `Run: prepared`; a handoff that merely exists, e.g. in the prepare
  window that just wrote it, does not count; remembered for the window,
  so deleting the handoff at the commit does not move the line):
  RUN_LIMIT;
- a plan run's supervisor (a prompt that is the go prompt `go: run plan`
  or `carry on running plan`, or a Bash/PowerShell call that launches
  `py ... autoplan.py <name>`; remembered for the window the same way):
  RUN_LIMIT, because it reports every phase of a plan in one window;
- any other app window (a prepare, a quick fix, a plan interview):
  LIMIT, lower, because what grows there is the
  model's own output (specs, thinking), and two prepare windows went
  from 42k to 140k with one Explore call each (review of 2026-10-01).

Subagents (Explore, Plan, general-purpose, claude-code-guide, implementer,
implementer-wt, reviewer, plan-reviewer, plan-writer):
- PreToolUse: warns at SOFT x its line, says to stop reading past it.
  Advisory only; a model can ignore it.
- PreToolUse: past HARD x its line, every further tool call is DENIED with
  an instruction to write the report now. This is the enforcement: a
  subagent cannot drift past 1.25x its line. A Write or Edit under
  .claude/specs/reports/ stays allowed, so the report can still land.
- SubagentStop: logs the peak to a per-session ledger; the main session's
  next hook run reports it.

Warnings are printed once per threshold crossing (90% / 80%, then the
line), not on every tool call: past the line every call used to repeat
the warning (one session got it 25 times), each one costing tokens in
the window it was protecting. The crossing state is
`<session dir>/context-watch.state.json`; a new prompt (UserPromptSubmit)
repeats the current state once, so a fresh turn starts informed. The
deny past HARD is not a warning and stays on every call.

transcript_path is always the parent session's transcript; a subagent's
own transcript is agent_transcript_path (SubagentStop) or derived from
agent_id. A subagent whose own transcript can't be found is skipped,
never measured from the parent's. Usage = input + cache read + cache
creation of the last turn after the last compact boundary (none yet
after a compaction: no reading).
Never fails the hook: any error exits 0 (and allows the tool).
"""
import json
import os
import re
import sys

LIMIT = 120_000       # app windows that are not a prepared run
RUN_LIMIT = 175_000   # a prepared run's window, or a plan run's supervisor
# the go prompt that starts a prepared run (workflow.md "The go prompt")
RUN_PROMPT = re.compile(r"\bgo:.*handoff\.md", re.I | re.S)
SUPERVISOR_PROMPT = re.compile(r"go: run plan |carry on running plan ")
# py / py.exe / python / python3 / python3.12 (bare, as a path, quoted or
# not), an optional -3 / -3.12, then a path ending in autoplan.py (quoted
# paths may hold spaces) and a word. `grep autoplan.py`, `cat
# tools/autoplan.py` and `py tools/autoplan.py --dry-run x` do not match.
SUPERVISOR_CMD = re.compile(
    r"(?:^|[\s;&|(\"'/\\])py(?:thon[\d.]*)?(?:\.exe)?[\"']?\s+"
    r"(?:-3(?:\.\d+)?\s+)?"
    r"(?:\"[^\"\n]*autoplan\.py\"|'[^'\n]*autoplan\.py'|[^\s\"']*autoplan\.py)"
    r"\s+\w")
SOFT = 0.8            # subagents: warn from this fraction of a line
MAIN_SOFT = 0.9       # main session: warn from this fraction of its line
HARD = 1.25           # subagents: deny all tools from this multiple of the line

# Context line per subagent type. Explore and Plan carry a ~33k baseline
# (system prompt and tools) before reading anything, so their line is
# higher. Types not listed are measured on SubagentStop, never warned or
# denied.
SUB_LIMITS = {"Explore": 100_000, "Plan": 100_000,
              "general-purpose": 100_000, "claude-code-guide": 100_000,
              "implementer": 60_000, "implementer-wt": 60_000, "reviewer": 80_000,
              "plan-reviewer": 80_000, "plan-writer": 120_000}


def usage_total(u):
    return (u.get("input_tokens", 0)
            + u.get("cache_creation_input_tokens", 0)
            + u.get("cache_read_input_tokens", 0))


def context_tokens(path):
    size = os.path.getsize(path)
    with open(path, "rb") as f:
        f.seek(max(0, size - 600_000))
        tail = f.read().decode("utf-8", "ignore")
    for line in reversed(tail.splitlines()):
        if '"compact_boundary"' in line:
            try:
                o = json.loads(line)
            except ValueError:
                o = None
            if o and o.get("subtype") == "compact_boundary":
                # No turn since the last compaction: usage lines before the
                # boundary measure the old, pre-compaction context.
                return None
        if '"usage"' not in line:
            continue
        try:
            o = json.loads(line)
        except ValueError:
            continue
        u = (o.get("message") or {}).get("usage")
        if u:
            return usage_total(u)
    return None


def peak_tokens(path):
    peak = 0
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            if '"usage"' not in line:
                continue
            try:
                o = json.loads(line)
            except ValueError:
                continue
            u = (o.get("message") or {}).get("usage")
            if u:
                peak = max(peak, usage_total(u))
    return peak


def session_dir(transcript_path):
    p = os.path.normpath(transcript_path)
    if os.path.basename(os.path.dirname(p)) == "subagents":
        return os.path.dirname(os.path.dirname(p))
    return os.path.splitext(p)[0]


def ledger_path(transcript_path):
    return os.path.join(session_dir(transcript_path), "context-watch.jsonl")


def state_path(transcript_path):
    return os.path.join(session_dir(transcript_path), "context-watch.state.json")


def read_state(transcript_path):
    try:
        with open(state_path(transcript_path), encoding="utf-8") as f:
            s = json.load(f)
    except (OSError, ValueError):
        s = {}
    if not isinstance(s, dict):
        s = {}
    s.setdefault("main", {})
    s.setdefault("agents", {})
    return s


def write_state(transcript_path, s):
    sp = state_path(transcript_path)
    try:
        os.makedirs(os.path.dirname(sp), exist_ok=True)
        tmp = sp + f".{os.getpid()}.tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(s, f)
        os.replace(tmp, sp)
    except OSError:
        pass


def own_transcript(d):
    atp = d.get("agent_transcript_path")
    if atp and os.path.exists(atp):
        return atp
    path, agent_id = d.get("transcript_path"), d.get("agent_id")
    if not (path and agent_id):
        return None
    cand = os.path.join(session_dir(path), "subagents", f"agent-{agent_id}.jsonl")
    return cand if os.path.exists(cand) else None


def report_write(d):
    """Past HARD the agent must still be able to write its report: a Write
    or Edit under .claude/specs/reports/ (agents return only its path)."""
    if d.get("tool_name") not in ("Write", "Edit"):
        return False
    p = ((d.get("tool_input") or {}).get("file_path") or "").replace("\\", "/")
    return "/.claude/specs/reports/" in p or p.startswith(".claude/specs/reports/")


def tier_of(used, limit, soft):
    if used >= limit:
        return 2
    if used >= limit * soft:
        return 1
    return 0


def main_line(d, state):
    """(limit, kind) for this app window; kind is "run", "supervisor" or ""."""
    env = os.environ.get("AUTOPLAN_LINE")
    if env:
        try:
            return int(env), ""
        except ValueError:
            pass
    kind = state["main"].get("run")
    if kind:
        return RUN_LIMIT, ("supervisor" if kind == "supervisor" else "run")
    text = d.get("prompt") or ""
    if not text and d.get("tool_name") in ("Bash", "PowerShell"):
        text = (d.get("tool_input") or {}).get("command") or ""
    if SUPERVISOR_PROMPT.search(text) or SUPERVISOR_CMD.search(text):
        kind = "supervisor"
    elif d.get("hook_event_name") == "UserPromptSubmit" and RUN_PROMPT.search(text):
        # only the go prompt makes a run window: a handoff that merely
        # exists (the prepare window that just wrote it, another
        # session's checkout) does not
        try:
            hand = os.path.join(d.get("cwd") or os.getcwd(), ".claude", "handoff.md")
            with open(hand, encoding="utf-8", errors="ignore") as f:
                if f.readline().strip() == "Run: prepared":
                    kind = "run"
        except OSError:
            pass
    if kind:
        # the line moved: tiers crossed under the old line no longer hold
        state["main"]["run"] = kind
        state["main"]["tier"] = 0
        return RUN_LIMIT, kind
    return LIMIT, ""


def main_message(used, limit, tier, kind):
    pct = used * 100 // limit
    if tier == 2:
        if kind == "supervisor":
            return (f"CONTEXT WATCH: {used:,} tokens in context, past the "
                    f"supervisor line of {limit:,}. Launch nothing new: "
                    "finish the phase report and end with the go prompt "
                    "('carry on running plan <name>'), as run.md says.")
        if kind or os.environ.get("AUTOPLAN_LINE"):
            return (f"CONTEXT WATCH: {used:,} tokens in context, past the "
                    f"handoff line of {limit:,}. Finish only the current "
                    "atomic step (an implementer already running may "
                    "finish; start nothing new), verify, commit, then follow "
                    "your mode file's 'Context full' rule.")
        return (f"CONTEXT WATCH: {used:,} tokens in context, past this "
                f"window's line of {limit:,}. Finish only the spec or step "
                "you are on, write .claude/handoff.md (handoff skill: Next "
                "lists what is still to write or do, with the anchors you "
                "already have), and end the turn as 'Context budget' says. "
                "Read nothing more yourself.")
    if tier == 1:
        return (f"CONTEXT WATCH: {used:,} tokens in context ({pct}% of "
                f"the line of {limit:,}). Prefer finishing over starting "
                "new work; read nothing more yourself (Explore brings "
                "anchors and excerpts).")
    return None


def sub_message(used, limit, tier, who):
    pct = used * 100 // limit
    if tier == 2:
        return (f"CONTEXT WATCH: {used:,} tokens in your context, past the "
                f"subagent line of {limit:,}. Stop exploring: finish only "
                "from what you already have. At "
                f"{int(limit * HARD):,} every tool call will be refused, so "
                "write your report soon and say in it that you hit the "
                "context line.")
    if tier == 1:
        return (f"CONTEXT WATCH: {used:,} tokens in your context ({pct}% of "
                "the subagent line). Read no more whole files; grep and "
                "read small ranges only; pipe command output through tail.")
    return None


def emit(event, msg):
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": event, "additionalContext": msg}}))


def on_subagent_stop(d):
    path = d.get("transcript_path")
    # Never measure a subagent from the parent's transcript (the compaction
    # agent has no transcript of its own).
    sub = own_transcript(d)
    if not (path and sub):
        return
    agent_id = d.get("agent_id")
    agent_type = d.get("agent_type") or "subagent"
    peak = peak_tokens(sub)
    limit = SUB_LIMITS.get(agent_type)
    try:
        with open(ledger_path(path), "a", encoding="utf-8") as f:
            f.write(json.dumps({"agent_id": agent_id, "agent_type": agent_type,
                                "peak": peak, "limit": limit,
                                "reported": False}) + "\n")
    except OSError:
        pass
    if limit is None:
        msg = f"SUBAGENT CONTEXT: {agent_type} {agent_id} peaked at {peak:,} tokens"
    else:
        over = " - OVER THE LINE" if peak >= limit else ""
        msg = (f"SUBAGENT CONTEXT: {agent_type} {agent_id} peaked at "
               f"{peak:,} tokens (line {limit:,})" + over)
    print(json.dumps({"systemMessage": msg}))


def on_subagent_tool(d, ev):
    agent_type = d.get("agent_type") or ""
    limit = SUB_LIMITS.get(agent_type)
    if limit is None:
        return
    own = own_transcript(d)
    if own is None:
        return
    used = context_tokens(own)
    if used is None:
        return
    if ev == "PreToolUse" and used >= limit * HARD and not report_write(d):
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": (
                f"CONTEXT WATCH: {used:,} tokens, past your hard line of "
                f"{int(limit * HARD):,}. No more tool calls. Write your "
                "report now from what you have (Write to .claude/specs/reports/ "
                "is still allowed; for the implementer: "
                "files changed, verification so far, what is left), and "
                "say you hit the context line so the task must be "
                "narrowed or split.")}}))
        return
    tier = tier_of(used, limit, SOFT)
    path, agent_id = d.get("transcript_path"), str(d.get("agent_id"))
    if not path:
        return
    state = read_state(path)
    if tier <= int(state["agents"].get(agent_id, 0)):
        return
    state["agents"][agent_id] = tier
    write_state(path, state)
    msg = sub_message(used, limit, tier, f"{agent_type} subagent")
    if msg:
        emit(ev, msg)


def ledger_messages(path):
    lp = ledger_path(path)
    if not os.path.exists(lp):
        return []
    parts, entries, changed = [], [], False
    with open(lp, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                try:
                    entries.append(json.loads(line))
                except ValueError:
                    pass
    for e in entries:
        if e.get("reported") is not False:
            continue
        peak, limit = e.get("peak", 0), e.get("limit")
        msg = (f"SUBAGENT CONTEXT: {e.get('agent_type')} {e.get('agent_id')} "
               f"peaked at {peak:,} tokens")
        if limit is not None and peak >= limit:
            msg += (f" - over the {limit:,} line: its prompt let it read too "
                    "much; make the next spec or Explore prompt narrower "
                    "(file, function, line range) or split the task.")
        parts.append(msg)
        e["reported"] = True
        changed = True
    if changed:
        tmp = lp + ".tmp"
        try:
            with open(tmp, "w", encoding="utf-8") as f:
                for e in entries:
                    f.write(json.dumps(e) + "\n")
            os.replace(tmp, lp)
        except OSError:
            pass
    return parts


def on_main(d, ev, path):
    parts = []
    state = read_state(path)
    if os.path.exists(path):
        used = context_tokens(path)
        if used is not None:
            limit, kind = main_line(d, state)
            tier = tier_of(used, limit, MAIN_SOFT)
            last = int(state["main"].get("tier", 0))
            # a new prompt repeats the current state once; a tool call
            # speaks only when a threshold is crossed
            if tier > last or (ev == "UserPromptSubmit" and tier > 0):
                m = main_message(used, limit, tier, kind)
                if m:
                    parts.append(m)
            state["main"]["tier"] = max(tier, last)
            write_state(path, state)
    try:
        parts += ledger_messages(path)
    except OSError:
        pass
    if not parts:
        return
    msg = "\n".join(parts)
    if ev in ("PreToolUse", "PostToolUse"):
        emit(ev, msg)
    else:
        print(msg)


def main():
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass
    d = json.load(sys.stdin)
    ev = d.get("hook_event_name")
    path = d.get("transcript_path")

    if ev == "SubagentStop":
        on_subagent_stop(d)
        return
    if d.get("agent_id"):
        if ev in ("PreToolUse", "PostToolUse"):
            on_subagent_tool(d, ev)
        return
    if not path:
        return
    on_main(d, ev, path)


try:
    main()
except Exception:
    pass
