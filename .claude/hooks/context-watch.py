"""Context watch: keeps every context small, because quality drops as a
context grows, long before the window is full.

Main session (UserPromptSubmit, PostToolUse): warns from SOFT x LIMIT and
says to finish and hand off past LIMIT (CLAUDE.md "Context budget";
format in .claude/skills/handoff).

Subagents (Explore, Plan, implementer, implementer-wt, reviewer):
- PostToolUse: warns at SOFT x its line, says to stop reading past it.
  Advisory only; a model can ignore it.
- PreToolUse: past HARD x its line, every further tool call is DENIED with
  an instruction to write the report now. This is the enforcement: a
  subagent cannot drift to 240k tokens any more.
- SubagentStop: logs the peak to a per-session ledger; the main session's
  next hook run reports it.

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
import sys

LIMIT = 140_000     # main session: tokens in context that trigger the handoff
SOFT = 0.8          # warn from this fraction of a line
HARD = 1.5          # subagents: deny all tools from this multiple of the line

# Context line per subagent type. Explore and Plan carry a ~33k baseline
# (system prompt and tools) before reading anything, so their line is
# higher. Types not listed are measured on SubagentStop, never warned or
# denied.
SUB_LIMITS = {"Explore": 100_000, "Plan": 100_000,
              "implementer": 60_000, "implementer-wt": 60_000, "reviewer": 80_000}


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


def own_transcript(d):
    atp = d.get("agent_transcript_path")
    if atp and os.path.exists(atp):
        return atp
    path, agent_id = d.get("transcript_path"), d.get("agent_id")
    if not (path and agent_id):
        return None
    cand = os.path.join(session_dir(path), "subagents", f"agent-{agent_id}.jsonl")
    return cand if os.path.exists(cand) else None


def report_line(used, limit, who):
    pct = used * 100 // limit
    if used >= limit:
        if not who:
            return (f"CONTEXT WATCH: {used:,} tokens in context, past the "
                    f"handoff line of {limit:,}. Finish only the current "
                    "atomic step (an implementer already running may "
                    "finish; start nothing new), verify, commit, then follow "
                    "your mode file's 'Context full' rule.")
        return (f"CONTEXT WATCH: {used:,} tokens in your context, past the "
                f"subagent line of {limit:,}. Stop exploring: finish only "
                "from what you already have. At "
                f"{int(limit * HARD):,} every tool call will be refused, so "
                "write your report soon and say in it that you hit the "
                "context line.")
    if used >= limit * SOFT:
        if not who:
            return (f"CONTEXT WATCH: {used:,} tokens in context ({pct}% of "
                    "the handoff line). Prefer finishing over starting new "
                    "work.")
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
    limit = SUB_LIMITS.get(d.get("agent_type") or "")
    if limit is None:
        return
    own = own_transcript(d)
    if own is None:
        return
    used = context_tokens(own)
    if used is None:
        return
    if ev == "PreToolUse":
        if used >= limit * HARD:
            print(json.dumps({"hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": (
                    f"CONTEXT WATCH: {used:,} tokens, past your hard line of "
                    f"{int(limit * HARD):,}. No more tool calls. Write your "
                    "report now from what you have (for the implementer: "
                    "files changed, verification so far, what is left), and "
                    "say you hit the context line so the task must be "
                    "narrowed or split.")}}))
        return
    msg = report_line(used, limit, f"{d.get('agent_type')} subagent")
    if msg:
        emit("PostToolUse", msg)


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
    if ev == "PreToolUse" or not path:
        return  # main session: PreToolUse never blocks

    parts = []
    if os.path.exists(path):
        used = context_tokens(path)
        if used is not None:
            m = report_line(used, LIMIT, "")
            if m:
                parts.append(m)
    try:
        parts += ledger_messages(path)
    except OSError:
        pass
    if not parts:
        return
    msg = "\n".join(parts)
    if ev == "PostToolUse":
        emit("PostToolUse", msg)
    else:
        print(msg)


try:
    main()
except Exception:
    pass
