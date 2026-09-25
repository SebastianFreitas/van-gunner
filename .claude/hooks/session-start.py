"""Session start: prints what a new context must know before its first move.

1. The mode (cloud / worktree / shared) and that mode's rules from
   .claude/modes/<mode>.md. CLAUDE.md keeps only the rules every mode
   shares, so each session loads one mode's rules instead of all three.
2. On a fresh start or /clear: the branch, and the paths already
   uncommitted (made by another session, never by this one).
3. On a fresh start or /clear: the handoff left by the previous context
   (.claude/handoff.md), if any.
4. In shared mode on a fresh start or /clear: the uncommitted paths are
   also written to `<session dir>/foreign-paths.json`, which git-guard
   reads to refuse staging them.
5. No Godot found: a warning line, since the check and smoke test cannot
   run.
6. After compaction: a reminder to re-read the active `docs/tasks/` file,
   if any exist.

SessionStart also fires after compaction ("compact") and on resume; the
mode rules are printed again then (compaction drops them), but not the
dirty-path list, which by then holds this session's own edits.

Plain stdout on SessionStart is added to the session's context.
Never fails the hook: any error exits 0.
"""
import glob
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

LIMIT = 9500          # hook output over 10,000 chars becomes a 2,000-char preview
HANDOFF_MAX = 6000
DIRTY_MAX = 40
CUT = ("\n[handoff cut to fit the hook output limit; read "
       ".claude/handoff.md for the rest]")


def git(*args):
    try:
        out = subprocess.run(["git", *args], capture_output=True, text=True,
                             timeout=10)
        return out.stdout.rstrip()  # a leading space is part of `git status --short`
    except Exception:
        return ""


def same(a, b):
    return os.path.normcase(os.path.abspath(a)) == os.path.normcase(os.path.abspath(b))


def session_dir(transcript_path: str) -> str:
    p = os.path.normpath(transcript_path)
    if os.path.basename(os.path.dirname(p)) == "subagents":
        return os.path.dirname(os.path.dirname(p))
    return os.path.splitext(p)[0]


def detect(root):
    if os.environ.get("CLAUDE_CODE_REMOTE") == "true":
        return "cloud", ""
    common = git("rev-parse", "--path-format=absolute", "--git-common-dir")
    main_root = os.path.dirname(common) if common else ""
    top = git("rev-parse", "--show-toplevel") or root
    if main_root and not same(main_root, top):
        return "worktree", main_root
    return "shared", main_root


def mode_rules(root, mode):
    for base in (os.path.join(root, ".claude", "modes"),
                 os.path.join(HERE, "..", "modes")):
        p = os.path.join(base, mode + ".md")
        if os.path.exists(p):
            with open(p, encoding="utf-8", errors="ignore") as f:
                return f.read().strip()
    return (f"(.claude/modes/{mode}.md not found: follow CLAUDE.md and say "
            "in the report that the mode file is missing.)")


def godot_missing(root: str) -> bool:
    try:
        sys.path.insert(0, os.path.join(root, "tools"))
        import godot_env
        return godot_env.find_godot() is None
    except Exception:
        return False


def dirty_paths(dirty):
    paths = []
    for line in dirty.splitlines():
        if not line.strip():
            continue
        p = line[3:]
        if " -> " in p:
            old, new = p.split(" -> ", 1)
            paths.append(old.strip('"'))
            paths.append(new.strip('"'))
        else:
            paths.append(p.strip('"'))
    return paths


def write_foreign_paths(transcript_path, paths):
    if not transcript_path:
        return
    fp = os.path.join(session_dir(transcript_path), "foreign-paths.json")
    try:
        os.makedirs(os.path.dirname(fp), exist_ok=True)
        with open(fp, "w", encoding="utf-8") as f:
            json.dump(paths, f)
    except OSError:
        pass


def main():
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass
    d = json.load(sys.stdin)
    source = d.get("source") or "startup"
    root = d.get("cwd") or os.getcwd()
    os.chdir(root)
    mode, main_root = detect(root)
    branch = git("branch", "--show-current") or "(detached)"
    lines = []

    def add_dirty(dirty):
        rows = dirty.splitlines()
        lines.extend("  " + l for l in rows[:DIRTY_MAX])
        if len(rows) > DIRTY_MAX:
            lines.append(f"  ... and {len(rows) - DIRTY_MAX} more "
                         "(git status --short)")

    head = git("status", "-sb").splitlines()
    where = f"branch {branch} at {root}"
    if mode == "worktree":
        where += f"; main checkout {main_root}"
    lines.append(f"MODE: {mode} ({where}). "
                 + (head[0] if head else ""))
    lines.append(mode_rules(root, mode))
    if godot_missing(root):
        lines.append(
            "NO GODOT: tools/godot_env.py found no Godot executable (GODOT "
            "unset, no godot on PATH). tools/check.py and tools/smoke.py "
            "cannot run: say so in the report. Cloud: the environment's "
            "setup script must run `bash tools/cloud_setup.sh`.")
    lines.append("")

    hand_at = None
    if source in ("startup", "clear"):
        dirty = git("status", "--short")
        if dirty and mode == "shared":
            lines.append("Edits already in the tree at session start. "
                         "Another session made them, not you: never stage, "
                         "revert, stash or 'clean up' these paths. Stage "
                         "your own files by path.")
            add_dirty(dirty)
            write_foreign_paths(d.get("transcript_path"), dirty_paths(dirty))
        elif dirty:
            lines.append("Uncommitted edits in this checkout at session "
                         "start (left by the previous context on this "
                         "branch; check the handoff before touching them):")
            add_dirty(dirty)
        else:
            lines.append("Tree clean at session start.")
            if mode == "shared":
                write_foreign_paths(d.get("transcript_path"), [])

        hand = os.path.join(root, ".claude", "handoff.md")
        if os.path.exists(hand):
            with open(hand, encoding="utf-8", errors="ignore") as f:
                body = f.read().strip()
            raw = body[:HANDOFF_MAX]
            if len(body) > HANDOFF_MAX:
                body = raw + CUT
            lines.append("")
            lines.append("HANDOFF from the previous context "
                         "(.claude/handoff.md). Restate the plan in two "
                         "lines, continue from 'Next', never redo 'Done', "
                         "and delete the file once absorbed:")
            hand_at = len(lines)
            lines.append(body)

    if source == "compact":
        names = sorted(
            os.path.relpath(p, root).replace(os.sep, "/")
            for p in glob.glob(os.path.join(root, "docs", "tasks", "*.md")))
        if names:
            lines.append("If you are working a task file, re-read it now "
                         "(CLAUDE.md Active task): " + ", ".join(names))

    out = "\n".join(lines)
    if len(out) > LIMIT and hand_at is not None:
        excess = len(out) - LIMIT
        keep = max(0, len(raw) - excess - len(CUT))
        lines[hand_at] = raw[:keep] + CUT
        out = "\n".join(lines)
    if len(out) > LIMIT:
        out = out[:LIMIT]
    print(out)


try:
    main()
except Exception:
    pass
