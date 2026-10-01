"""Go check (UserPromptSubmit): a go prompt names the checkout and branch
it was written for (`.claude/rules/workflow.md` "The go prompt":
`... Checkout <path> on branch <branch> ...`). This hook compares them
with the session's own toplevel and branch and prints one line either
way, so the fresh window never guesses where it is (owner, 2026-10-01:
after /clear and "go" it "doesn't know which worktree is it, or
branch").

- `GO CHECK: ok ...` when both match (path compared case-insensitively
  with slashes normalised; branch exactly).
- `GO CHECK: MISMATCH ...` otherwise, with the rule: stop and tell the
  owner, never switch checkout or branch.

Prompts without a `Checkout ... on branch ...` clause print nothing.
Never fails the hook: any error exits 0.
"""
import json
import os
import re
import subprocess
import sys

CLAUSE = re.compile(r"checkout\s+(\S+?)\s+on\s+branch\s+(\S+?)(?=[\s,.;]|$)",
                    re.IGNORECASE)


def git(*args):
    try:
        out = subprocess.run(["git", *args], capture_output=True, text=True,
                             timeout=10)
        return out.stdout.strip()
    except Exception:
        return ""


def norm(path):
    p = path.strip().strip("`'\"").rstrip("/\\")
    p = os.path.abspath(p)
    return os.path.normcase(p).replace("\\", "/")


def main():
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass
    d = json.load(sys.stdin)
    prompt = d.get("prompt") or ""
    m = CLAUSE.search(prompt)
    if not m:
        return
    want_path = m.group(1).strip("`'\"").rstrip(",.;")
    want_branch = m.group(2).strip("`'\"").rstrip(",.;")
    root = d.get("cwd") or os.getcwd()
    try:
        os.chdir(root)
    except OSError:
        pass
    have_path = git("rev-parse", "--show-toplevel") or root
    have_branch = git("branch", "--show-current") or "(detached)"
    path_ok = norm(want_path) == norm(have_path)
    branch_ok = want_branch == have_branch
    here = f"this session is {have_path.replace(os.sep, '/')} on branch {have_branch}"
    if path_ok and branch_ok:
        print(f"GO CHECK: ok, {here}, as the prompt says.")
        return
    what = []
    if not path_ok:
        what.append(f"checkout (prompt: {want_path})")
    if not branch_ok:
        what.append(f"branch (prompt: {want_branch})")
    print(f"GO CHECK: MISMATCH on {' and '.join(what)}; {here}. "
          "The owner is in another session or folder: stop, say which "
          "checkout and branch the prompt names and where this session "
          "is, and do nothing else. Never switch checkout or branch to "
          "match the prompt (.claude/rules/workflow.md 'The go prompt').")


try:
    main()
except Exception:
    pass
