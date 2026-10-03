"""File guard (PreToolUse on Read, Write, Edit, MultiEdit, NotebookEdit, Bash,
PowerShell; runs
in the main session and inside subagents alike): keeps agents inside the
token and ownership rules that .claude/rules/workflow.md already states in
prose. Project-neutral: the project root is the first folder above the file
that holds a .git (file or folder, so worktrees work); a file outside any
repo is allowed.

- Read of a binary or cache file (images, audio, fonts, archives, anything
  under __pycache__/ or node_modules/) never earns its cost back; the caller
  should list the folder for names instead (workflow.md Token rules).
- Read of a text file over 300 lines without a limit of at most 300 would
  load the whole thing into context; grep -n for the symbol
  and read around it instead (same rule).
- Generated and tool-owned files each have a generator or an owner; a hand
  edit is either overwritten by the next run or silently drifts from what
  reads it. The project lists them in its config (`generated`).
- In the main session (no agent_id), source files are the implementer
  subagent's job, built from a spec (workflow.md Main session role); the main
  session itself may still make a single-line Edit.
- Bash and PowerShell writes to a source or generated file (redirects, tee,
  sed -i, cp/mv/install, python open(..., 'w'), Set-Content) are refused in
  the main session too: they skipped the Write/Edit check, and in cloud
  threads the main session wrote code itself that way (2026-10-03). Found by
  regex, not a shell parser; subagents may write source.

The project tunes this through an optional .claude/project/file-guard.json
(read once per call; missing or bad JSON means no config):
- binary_suffixes: extra suffixes added to the default binary set.
- cache_dirs: extra folder names added to the default cache folders.
- source_suffixes: replaces the default source suffix set when present.
- source_files: extra exact root-relative paths that count as source.
- generated: list of {"glob": "...", "why": "..."}; fnmatch on the
  root-relative path, first hit wins; a write to a hit is always refused
  with "<path> is <why>." (a missing or empty why gets a default reason).
- quiet_dirty: globs (same matching as generated) for paths a tool rewrites
  all the time; session-start and git-guard count them in one line instead
  of listing them, but still record them as foreign. Not used here.
Loading and glob matching live in guard_config.py, shared with the other
hooks that read this file.

Never fails the hook: any error allows the call (exit 0).
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from guard_config import load_config, matches_any, source_rule  # noqa: E402

BINARY_SUFFIXES = {
    ".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tga", ".exr", ".hdr",
    ".wav", ".ogg", ".mp3", ".import", ".ttf", ".otf", ".woff", ".woff2",
    ".glb", ".fbx", ".blend", ".res", ".scn", ".ctex", ".pck", ".zip",
    ".exe", ".dll", ".so", ".pyc",
    ".gif", ".ico", ".mp4", ".webm", ".mov", ".m4a", ".flac", ".pdf",
    ".psd", ".7z", ".gz", ".tar",
}
CACHE_DIR_NAMES = {"__pycache__", "node_modules", ".git"}
WRITE_TOOLS = {"Write", "Edit", "MultiEdit", "NotebookEdit"}
DEFAULT_WHY = "generated or tool-owned (see .claude/project/file-guard.json)"

MAX_LINES = 300
MAX_READ_BYTES = 50 * 1024 * 1024


def ext(path: str) -> str:
    return os.path.splitext(path)[1].lower()


def find_root(path: str) -> str | None:
    # walk up from the file's folder to the first .git (a file in a
    # worktree); a file outside any repo (scratchpad) allows.
    d = os.path.dirname(path)
    while True:
        if os.path.exists(os.path.join(d, ".git")):
            return d
        parent = os.path.dirname(d)
        if parent == d:
            return None
        d = parent


def deny(reason: str) -> None:
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": reason,
    }}))


def read_violation(path: str, rel: str, tool_input: dict, cfg: dict) -> str | None:
    binary = BINARY_SUFFIXES | {s.lower() for s in cfg.get("binary_suffixes") or []}
    caches = CACHE_DIR_NAMES | set(cfg.get("cache_dirs") or [])
    parts = rel.split("/")
    if ext(path) in binary or any(p in caches for p in parts):
        return (f"{rel} is a binary or cache file; list its folder for "
                 "names only (.claude/rules/workflow.md Token rules).")
    if not os.path.isfile(path):
        return None
    if os.path.getsize(path) >= MAX_READ_BYTES:
        return None
    with open(path, "rb") as f:
        data = f.read()
    lines = data.count(b"\n")
    if data and not data.endswith(b"\n"):
        lines += 1
    limit = tool_input.get("limit")
    if lines > MAX_LINES and (limit is None or int(limit) > MAX_LINES):
        return (f"{rel} has {lines} lines. Grep -n for the name you need, "
                 "then Read with offset and a limit of at most 300 "
                 "(.claude/rules/workflow.md Token rules).")
    return None


def generated_reason(rel: str, cfg: dict) -> str | None:
    # First hit in the project's list wins; a hit without a why still denies.
    for entry in cfg.get("generated") or []:
        if isinstance(entry, dict) and matches_any(rel, [str(entry.get("glob", ""))]):
            return str(entry.get("why") or "") or DEFAULT_WHY
    return None


def edit_pairs(tool_name: str, tool_input: dict) -> list[tuple[str, str]]:
    if tool_name == "Edit":
        return [(tool_input.get("old_string", ""), tool_input.get("new_string", ""))]
    if tool_name == "MultiEdit":
        edits = tool_input.get("edits") or []
        return [(e.get("old_string", ""), e.get("new_string", "")) for e in edits]
    return []


def main_session_violation(tool_name: str, tool_input: dict) -> bool:
    if tool_name == "Write":
        return True
    if tool_name == "Edit":
        old = tool_input.get("old_string", "")
        new = tool_input.get("new_string", "")
        return bool("\n" in old.strip("\n") or "\n" in new.strip("\n")
                     or tool_input.get("replace_all"))
    if tool_name == "MultiEdit":
        edits = tool_input.get("edits") or []
        if len(edits) > 1:
            return True
        return any("\n" in e.get("old_string", "").strip("\n")
                   or "\n" in e.get("new_string", "").strip("\n") for e in edits)
    if tool_name == "NotebookEdit":
        return True
    return False


def unquote(word: str) -> str:
    return word.strip().strip("'\"")


def bash_write_targets(command: str) -> list[str]:
    out: list[str] = []
    for m in re.finditer(r"(?<![\w<>&-])(\d?)>>?(?!&)[ \t]*([^\s;|&<>()]+)", command):
        if m.group(1) in ("", "1") and unquote(m.group(2)) != "/dev/null":
            out.append(unquote(m.group(2)))
    start = r"(?:^|[\s;|&(])"
    for m in re.finditer(start + r"tee\b([^\n;|&]*)", command):
        out += [unquote(w) for w in m.group(1).split() if not w.startswith("-")]
    for m in re.finditer(start + r"sed\b([^\n|&]*)", command):
        args = m.group(1)
        if re.search(r"\s(-[A-Za-z]*i\S*|--in-place\S*)(?=\s|$)", args):
            out += [unquote(w) for w in args.split() if not w.startswith("-")]
    for m in re.finditer(start + r"(?:cp|mv|install)\s+([^\n;|&]*)", command):
        words = [unquote(w) for w in m.group(1).split() if not w.startswith("-")]
        if words:
            out.append(words[-1])
    if re.search(r"\b(?:python3?|py)\b", command):
        out += re.findall(r"open\(\s*['\"]([^'\"]+)['\"]\s*,\s*['\"][wax]", command)
        out += re.findall(
            r"Path\(\s*['\"]([^'\"]+)['\"]\s*\)\.write_(?:text|bytes)\(", command)
    for m in re.finditer(r"(?i)\b(?:Set-Content|Add-Content|Out-File)\b([^\n;|]*)", command):
        args = m.group(1)
        named = re.search(r"(?i)-(?:File)?Path\s+(\S+)", args)
        if named:
            out.append(unquote(named.group(1)))
        else:
            words = [w for w in args.split() if not w.startswith("-")]
            if words:
                out.append(unquote(words[0]))
    return out


def bash_violation(d: dict, tool_input: dict) -> None:
    command = tool_input.get("command") or ""
    base = d.get("cwd") or os.getcwd()
    for target in bash_write_targets(command):
        path = os.path.abspath(os.path.join(base, target))
        root = find_root(path)
        if root is None:
            continue
        rel = os.path.relpath(path, root).replace("\\", "/")
        cfg = load_config(root)
        why = generated_reason(rel, cfg)
        if why is not None:
            deny(f"{rel} is {why}.")
            return
        suffixes, source_files = source_rule(cfg)
        if ext(path) in suffixes or rel in source_files:
            deny(f"Main session: {rel} is a source file; Bash writes to source "
                 "files are refused like Write/Edit. Write a spec and hand it to "
                 "the implementer subagent (.claude/rules/workflow.md Main "
                 "session role).")
            return


def main() -> None:
    d = json.load(sys.stdin)
    tool_name = d.get("tool_name") or ""
    tool_input = d.get("tool_input") or {}
    if tool_name in ("Bash", "PowerShell"):
        if not d.get("agent_id"):
            bash_violation(d, tool_input)
        return
    path =tool_input.get("file_path") or tool_input.get("notebook_path")
    if not path:
        return
    cwd = d.get("cwd") or os.getcwd()
    if not os.path.isabs(path):
        path = os.path.join(cwd, path)
    path = os.path.abspath(path)

    root = find_root(path)
    if root is None:
        return
    rel = os.path.relpath(path, root).replace("\\", "/")
    cfg = load_config(root)

    if tool_name == "Read":
        reason = read_violation(path, rel, tool_input, cfg)
        if reason:
            deny(reason)
        return

    if tool_name not in WRITE_TOOLS:
        return

    why = generated_reason(rel, cfg)
    if why is not None:
        deny(f"{rel} is {why}.")
        return

    if d.get("agent_id"):
        return
    suffixes, source_files = source_rule(cfg)
    if ext(path) not in suffixes and rel not in source_files:
        return
    if not main_session_violation(tool_name, tool_input):
        return
    listed = " ".join(sorted(suffixes) + source_files)
    deny(f"Main session: source files ({listed}) are changed by the "
         "implementer subagent from a spec (.claude/rules/workflow.md Main "
         "session role). The only exception is a single-line Edit.")


try:
    main()
except Exception:
    pass
