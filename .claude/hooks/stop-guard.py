"""Stop guard (Stop, main session): in worktree and cloud mode, the turn
may not end with work that the owner's Ship command would miss.

- Worktree or cloud: uncommitted or untracked (not ignored) files -> block
  once, asking to commit them by path, or to say why they stay.
- Cloud: commits not pushed to the branch's remote -> block once.
- Worktree or cloud: Godot files changed on the branch (vs its merge-base
  with main) after the last clean `tools/check.py` -> block once; runtime
  files (under `scripts/`, `scenes/`, `resources/`, `tools/smoke/`, or
  `project.godot`) also need a clean `tools/smoke.py`, and van scenes
  (`scenes/van/`, `scenes/ui/run_hud.tscn`) a clean `tools/scene_dump.py`.
  The tools record clean runs in `.godot/claude-verify.json`
  (`tools/godot_env.py` `stamp_clean`).

Shared mode is never checked: foreign edits make "uncommitted" meaningless
there. A second stop in a row (stop_hook_active) always passes, so the
session can end a turn deliberately (a question for the owner, a blocker).
Never fails the hook: any error exits 0.
"""
import json
import os
import subprocess
import sys

GODOT_EXT = (".gd", ".tscn", ".tres", ".gdshader", ".gdshaderinc")
RUNTIME_PREFIXES = ("scripts/", "scenes/", "resources/", "tools/smoke/")
VAN_SCENES = ("scenes/van/", "scenes/ui/run_hud.tscn")


def git(*args, strip=True):
    try:
        out = subprocess.run(["git", *args], capture_output=True, text=True,
                             timeout=10)
        return out.stdout.strip() if strip else out.stdout
    except Exception:
        return ""


def same(a, b):
    return os.path.normcase(os.path.abspath(a)) == os.path.normcase(os.path.abspath(b))


def mode():
    if os.environ.get("CLAUDE_CODE_REMOTE") == "true":
        return "cloud"
    common = git("rev-parse", "--path-format=absolute", "--git-common-dir")
    top = git("rev-parse", "--show-toplevel")
    if common and top and not same(os.path.dirname(common), top):
        return "worktree"
    return "shared"


def unverified(mode: str) -> list[str]:
    root = git("rev-parse", "--show-toplevel")
    if not root:
        return []
    base = git("merge-base", "HEAD", "main") or git("merge-base", "HEAD", "origin/main")
    if not base:
        return []
    changed = (set(git("diff", "--name-only", base).splitlines())
               | set(git("ls-files", "--others", "--exclude-standard").splitlines()))
    changed.discard("")
    godot = [p for p in changed if p.endswith(GODOT_EXT) or p == "project.godot"]
    if not godot:
        return []

    def change_time(p):
        full = os.path.join(root, p)
        if os.path.exists(full):
            return os.path.getmtime(full)
        return float(git("log", "-1", "--format=%ct") or 0)

    try:
        with open(os.path.join(root, ".godot", "claude-verify.json"),
                  encoding="utf-8") as f:
            stamps = json.load(f)
    except Exception:
        stamps = {}

    py = "python3" if mode == "cloud" else "py -3"
    problems = []
    for kind, paths, command in (
        ("check", godot, "tools/check.py"),
        ("smoke", [p for p in godot if p.startswith(RUNTIME_PREFIXES)
                   or p == "project.godot"], "tools/smoke.py"),
        ("scene_dump", [p for p in godot if p.startswith(VAN_SCENES)],
         "tools/scene_dump.py"),
    ):
        if not paths:
            continue
        newest = max(paths, key=change_time)
        if stamps.get(kind, 0) < change_time(newest):
            problems.append(f"{newest} changed after the last clean {py} {command}")
    return problems


def main():
    d = json.load(sys.stdin)
    if d.get("stop_hook_active"):
        return
    os.chdir(d.get("cwd") or os.getcwd())
    m = mode()
    if m == "shared":
        return
    problems = []
    dirty = git("status", "--porcelain", strip=False)
    paths = [l[3:] for l in dirty.splitlines()
             if l.strip() and not l[3:].strip('"').endswith(".claude/handoff.md")]
    if paths:
        more = f" (+{len(paths) - 12} more)" if len(paths) > 12 else ""
        problems.append("uncommitted files: " + ", ".join(paths[:12]) + more
                        + ". The Ship command merges commits only")
    if m == "cloud":
        branch = git("branch", "--show-current")
        remote = (git("rev-parse", "--abbrev-ref", "@{upstream}")
                  or (f"origin/{branch}" if branch and git(
                      "rev-parse", "--verify", "--quiet", f"origin/{branch}")
                      else ""))
        if remote:
            ahead = git("rev-list", "--count", f"{remote}..HEAD")
            if ahead and ahead != "0":
                problems.append(f"{ahead} commit(s) not pushed")
        else:
            base = git("rev-list", "--count", "origin/main..HEAD")
            if base and base != "0":
                problems.append("the branch has never been pushed")
    problems.extend(unverified(m))
    if not problems:
        return
    print(json.dumps({"decision": "block", "reason": (
        f"Stop guard ({m} mode): " + "; ".join(problems) + ". Verify and "
        "commit by path" + (" and push" if m == "cloud" else "")
        + ", then end with the report. If you are stopping on purpose "
        "(a question for the owner, a blocker, a check you deliberately "
        "skipped), say so in one line and stop again.")}))


try:
    main()
except Exception:
    pass
