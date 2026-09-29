"""Scene id guard (PreToolUse on Edit, MultiEdit; runs in the main session
and inside subagents alike): an Edit that changes an id=, unique_id= or
uid:// value on an existing .tscn/.tres header line is refused. Those values
are referenced by id elsewhere in the file and by other files, and
renumbering one breaks every reference to it.

Never fails the hook: any error allows the call (exit 0).
"""
import json
import os
import re
import sys

# Matches an existing id=, unique_id= or uid:// value on a .tscn/.tres
# header line, so two headers can be compared with those values masked out.
TOKEN = re.compile(r'\b(?:id="[^"]*"|unique_id=\d+|uid="uid://[^"]*")')


def deny(reason: str) -> None:
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": reason,
    }}))


def edit_pairs(tool_name: str, tool_input: dict) -> list[tuple[str, str]]:
    if tool_name == "Edit":
        return [(tool_input.get("old_string", ""), tool_input.get("new_string", ""))]
    if tool_name == "MultiEdit":
        edits = tool_input.get("edits") or []
        return [(e.get("old_string", ""), e.get("new_string", "")) for e in edits]
    return []


def header_lines(text: str) -> list[str]:
    return [line for line in text.splitlines() if line.strip().startswith("[")]


def scene_id_violation(old_string: str, new_string: str) -> str | None:
    # A header line's id/unique_id/uid changed if, once those values are
    # masked out, it matches another header that differs from it verbatim.
    # A header whose path= also changed stays unequal after masking, so
    # repointing a resource to a different file is still allowed.
    for old in header_lines(old_string):
        if not TOKEN.search(old):
            continue
        masked_old = TOKEN.sub("#", old)
        for new in header_lines(new_string):
            if TOKEN.sub("#", new) == masked_old and new != old:
                return (f"This edit changes an id on an existing header line:\n"
                         f"{old.strip()}\n-> {new.strip()}\nNever change or "
                         "renumber existing id=, unique_id= or uid:// values; "
                         "new ids must not collide with ids already in the file.")
    return None


def main() -> None:
    d = json.load(sys.stdin)
    tool_name = d.get("tool_name") or ""
    tool_input = d.get("tool_input") or {}
    path = tool_input.get("file_path")
    if not path:
        return
    if os.path.splitext(path)[1].lower() not in (".tscn", ".tres"):
        return
    for old, new in edit_pairs(tool_name, tool_input):
        reason = scene_id_violation(old, new)
        if reason:
            deny(reason)
            return


try:
    main()
except Exception:
    pass
