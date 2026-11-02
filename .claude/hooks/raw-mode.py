"""Raw mode (UserPromptSubmit): a prompt that starts `raw:` (or is just
`raw`) makes this window do every step of the task in its own context,
for hard problems (owner, 2026-11-02: "our context has all steps done to
solve the asked task"). The flag is `<session dir>/raw-mode`; it stays
for the window and a new transcript (/clear, a new chat) has none.

The flag changes three guards, main session only:
- agent-guard: every Agent call is refused except the checkers of
  finished work (reviewer, look-judge).
- file-guard: source files may be written.
- context-watch: the window's line is RUN_LIMIT, and it does its own
  reading.

Every other hook, review-guard's reviewer included, works as usual.
Rules: workflow.md "Raw mode". Never fails the hook: any error exits 0.
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from guard_config import raw_flag, raw_mode  # noqa: E402

ON = re.compile(r"\s*raw\s*(:|$)", re.I)


def main():
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass
    d = json.load(sys.stdin)
    path = d.get("transcript_path")
    if not path or raw_mode(path) or not ON.match(d.get("prompt") or ""):
        return
    flag = raw_flag(path)
    os.makedirs(os.path.dirname(flag), exist_ok=True)
    with open(flag, "w", encoding="utf-8"):
        pass
    print("RAW MODE on for this window: read .claude/rules/workflow.md "
          "'Raw mode' and do every step here; only the reviewer and "
          "look-judge run, on finished work.")


try:
    main()
except Exception:
    pass
