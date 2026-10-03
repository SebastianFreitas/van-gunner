"""Godot session notes (SessionStart): what only Van Gunner needs on top of
the shared session-start hook.

- NO GODOT line when tools/godot_env.py finds no Godot executable, so the
  session says up front that check and smoke cannot run.
- After a compaction or /clear (source "compact" or "clear"), a reminder to re-read the task
  files in docs/tasks/.

Plain stdout text, like session-start.py. Nothing to say prints nothing.
Never fails the hook: any error exits 0.
"""
import glob
import json
import os
import subprocess
import sys


def git(*args):
    try:
        out = subprocess.run(["git", *args], capture_output=True, text=True,
                             timeout=10)
        return out.stdout.strip()
    except Exception:
        return ""


def godot_missing(root: str) -> bool:
    try:
        sys.path.insert(0, os.path.join(root, "tools"))
        import godot_env
        return godot_env.find_godot() is None
    except Exception:
        return False


def main():
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass
    d = json.load(sys.stdin)
    source = d.get("source") or "startup"
    os.chdir(d.get("cwd") or os.getcwd())
    root = git("rev-parse", "--show-toplevel")
    if not root:
        return
    # docs/PROJECT_MAP.md is gitignored, so every session builds it itself.
    gen = os.path.join(root, "tools", "gen_context.py")
    if os.path.exists(gen):
        try:
            subprocess.run([sys.executable, gen], cwd=root,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                           timeout=30)
        except Exception:
            pass
    lines = []
    if godot_missing(root):
        lines.append(
            "NO GODOT: tools/godot_env.py found no Godot executable (GODOT "
            "unset, no godot on PATH). tools/check.py and tools/smoke.py "
            "cannot run: say so in the report. Cloud: the environment's "
            "setup script must run `bash tools/cloud_setup.sh`.")
    if source in ("compact", "clear"):
        names = sorted(
            os.path.relpath(p, root).replace(os.sep, "/")
            for p in glob.glob(os.path.join(root, "docs", "tasks", "*.md")))
        if names:
            lines.append("If you are working a task file, re-read it now "
                         "(CLAUDE.md Active task): " + ", ".join(names))
    if lines:
        print("\n".join(lines))


try:
    main()
except Exception:
    pass
