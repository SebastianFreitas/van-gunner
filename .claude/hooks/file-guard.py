"""File guard (PreToolUse on Read, Write, Edit, MultiEdit, NotebookEdit; runs
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
  session itself may still make a single-line Edit. A session whose model
  the project exempts implements directly, so this rule skips it; the model
  is read from the transcript's tail.

The project tunes this through an optional .claude/project/file-guard.json
(read once per call; missing or bad JSON means no config):
- binary_suffixes: extra suffixes added to the default binary set.
- cache_dirs: extra folder names added to the default cache folders.
- source_suffixes: replaces the default source suffix set when present.
- source_files: extra exact root-relative paths that count as source.
- generated: list of {"glob": "...", "why": "..."}; fnmatch on the
  root-relative path, first hit wins; a write to a hit is always refused
  with "<path> is <why>." (a missing or empty why gets a default reason).
- main_session_exempt_models: lowercase substrings; a session model that
  contains one skips the main-session source rule.

Never fails the hook: any error allows the call (exit 0).
"""
import fnmatch
import json
import os
import re
import sys

BINARY_SUFFIXES = {
    ".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tga", ".exr", ".hdr",
    ".wav", ".ogg", ".mp3", ".import", ".ttf", ".otf", ".woff", ".woff2",
    ".glb", ".fbx", ".blend", ".res", ".scn", ".ctex", ".pck", ".zip",
    ".exe", ".dll", ".so", ".pyc",
    ".gif", ".ico", ".mp4", ".webm", ".mov", ".m4a", ".flac", ".pdf",
    ".psd", ".7z", ".gz", ".tar",
}
CACHE_DIR_NAMES = {"__pycache__", "node_modules", ".git"}
SOURCE_SUFFIXES = {
    ".py", ".js", ".mjs", ".cjs", ".ts", ".tsx", ".jsx", ".css", ".scss",
    ".html", ".gd", ".tscn", ".tres", ".gdshader", ".gdshaderinc", ".cs",
    ".cfg", ".sh",
}
WRITE_TOOLS = {"Write", "Edit", "MultiEdit", "NotebookEdit"}
CONFIG_PATH = ".claude/project/file-guard.json"
DEFAULT_WHY = "generated or tool-owned (see .claude/project/file-guard.json)"

MAX_LINES = 300
MAX_READ_BYTES = 50 * 1024 * 1024
TRANSCRIPT_TAIL_BYTES = 400_000

MODEL_RE = re.compile(r'"model"\s*:\s*"([^"]+)"')


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


def load_config(root: str) -> dict:
    try:
        with open(os.path.join(root, CONFIG_PATH), encoding="utf-8") as f:
            cfg = json.load(f)
    except (OSError, ValueError):
        return {}
    return cfg if isinstance(cfg, dict) else {}


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
        if isinstance(entry, dict) and fnmatch.fnmatchcase(rel, str(entry.get("glob", ""))):
            return str(entry.get("why") or "") or DEFAULT_WHY
    return None


def session_model(transcript_path: str | None) -> str:
    # Last "model" field logged in the transcript's tail, or "" on any
    # problem (no path, unreadable file, no match).
    if not transcript_path:
        return ""
    try:
        with open(transcript_path, "rb") as f:
            f.seek(0, os.SEEK_END)
            size = f.tell()
            f.seek(max(0, size - TRANSCRIPT_TAIL_BYTES))
            data = f.read()
    except OSError:
        return ""
    text = data.decode("utf-8", errors="ignore")
    matches = MODEL_RE.findall(text)
    return matches[-1] if matches else ""


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


def main() -> None:
    d = json.load(sys.stdin)
    tool_name = d.get("tool_name") or ""
    tool_input = d.get("tool_input") or {}
    path = tool_input.get("file_path") or tool_input.get("notebook_path")
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
    suffixes = SOURCE_SUFFIXES
    if "source_suffixes" in cfg:
        suffixes = {s.lower() for s in cfg["source_suffixes"] or []}
    source_files = list(cfg.get("source_files") or [])
    if ext(path) not in suffixes and rel not in source_files:
        return
    if not main_session_violation(tool_name, tool_input):
        return
    exempt = [m.lower() for m in cfg.get("main_session_exempt_models") or []]
    if exempt:
        model = session_model(d.get("transcript_path")).lower()
        if any(m in model for m in exempt):
            return
    listed = " ".join(sorted(suffixes) + source_files)
    deny(f"Main session: source files ({listed}) are changed by the "
         "implementer subagent from a spec (.claude/rules/workflow.md Main "
         "session role). The only exception is a single-line Edit.")


try:
    main()
except Exception:
    pass
