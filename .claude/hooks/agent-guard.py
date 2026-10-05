"""Agent guard (PreToolUse on Agent, main session and subagents): every
subagent call runs in the foreground (`run_in_background: false`).

The Agent tool launches in the background unless told otherwise. In this
workflow nothing happens in the window while a subagent works: the run
window only manages implementers, the prepare window waits for Explore.
A background implementer ends the turn while files are still being
written, the Stop guard (and a project's verify guard) then blocks, the
session says "stopping on purpose", the hand-back arrives as a new
message, and that cycle repeated for every spec (one session took 24
Stop-guard blocks and ended at 164k; 72 of 100 implementer launches had
no foreground flag; review of 2026-10-01). Parallel subagents are
several Agent calls in one message, which run at the same time and
return together, so the foreground loses nothing.

Under AUTOPLAN=1 a call with no run_in_background key passes too: the
headless CLI's Agent tool has no such field and runs every call in the
foreground (street-setbacks phase 1, 2026-10-05).

Never fails the hook: any error allows the call (exit 0).
"""
import json
import os
import sys


def main():
    d = json.load(sys.stdin)
    ti = d.get("tool_input") or {}
    if ti.get("run_in_background") is False:
        return
    # Headless autoplan sessions (AUTOPLAN=1) have no background agents, so
    # their Agent tool has no run_in_background field: a missing key is foreground.
    if os.environ.get("AUTOPLAN") == "1" and "run_in_background" not in ti:
        return
    who = ti.get("subagent_type") or "subagent"
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": (
            f"Agent guard: subagents run in the foreground here. Call the "
            f"{who} again with run_in_background: false (same prompt). A "
            "background subagent ends the turn while it is still writing, "
            "and the Stop guard then blocks every hand-back. Parallel "
            "subagents: several Agent calls in one message, all "
            "foreground.")}}))


try:
    main()
except Exception:
    pass
