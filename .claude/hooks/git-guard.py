"""Git guard (PreToolUse on Bash / PowerShell): other sessions edit this
tree at the same time, so blanket git commands are blocked (exit 2, the
reason goes back to the session). A plain `git commit` passes through (the
normal permission prompt still applies) and gets a note listing the
unstaged files that are staying out of it.

Also enforces the owner-only path to `main`/origin: the owner lands
branches with `py -3 tools/try.py <branch> --commit` and pushes with
GitHub Desktop. Sessions never push (except a cloud session pushing its
own non-main branch), never merge into `main`, never delete a branch or
remove a worktree, and never run `gh pr merge`.

In the main checkout (shared mode), `git checkout` / `git switch` are also
refused: the owner's GitHub Desktop and other sessions rely on it staying
on `main`.

`git add` naming a path listed in `<session dir>/foreign-paths.json`
(written by session-start.py in shared mode: paths already uncommitted
when the session started) is refused too, so a session can't sweep up
another session's edits by path even when it avoids the blanket patterns
below.

Never blocks on its own failure: any error exits 0.
"""
import fnmatch
import json
import os
import re
import shlex
import subprocess
import sys

BLOCK = [
    (r"\bgit\s+add\b[^|;&\n]*(\s-A\b|\s--all\b|\s-u\b|\s--update\b|\s\.(\s|$)|\s\*)",
     "blanket 'git add' would stage another session's edits"),
    (r"\bgit\s+commit\b[^|;&\n]*(\s-a\b|\s-am\b|\s--all\b)",
     "'git commit -a' would commit another session's edits"),
    (r"\bgit\s+stash\b(?!\s+list)", "'git stash' would hide another session's edits"),
    (r"\bgit\s+checkout\s+(--|\.)", "'git checkout --' would discard another session's edits"),
    (r"\bgit\s+restore\b(?![^|;&\n]*--staged)", "'git restore' would discard another session's edits"),
    (r"\bgit\s+reset\s+--hard", "'git reset --hard' would discard another session's edits"),
    (r"\bgit\s+clean\b", "'git clean' would delete another session's files"),
    (r"\bgit\s+rebase\b", "rebasing on a shared dirty tree; merge instead"),
    (r"\bgit\s+push\b[^|;&\n]*(\s-f\b|\s--force\b)", "force push"),
]

# Owner-only path to main/origin: checked separately from BLOCK, either
# because the reason doesn't fit BLOCK's "foreign edits" message (gh pr
# merge, branch deletion, worktree removal) or because whether they block
# depends on the command's context (env var, mentioned branch, current
# branch), not the pattern alone.
GH_MERGE_RE = re.compile(r"\bgh\s+pr\s+merge\b")
BRANCH_DELETE_RE = re.compile(
    r"\bgit\b[^|;&\n]*\s(branch\s+(-d|-D|--delete)\b|push\s+\S+\s+--delete\b)")
WORKTREE_REMOVE_RE = re.compile(r"\bgit\s+worktree\s+remove\b")
PUSH_RE = re.compile(r"\bgit\b[^|;&\n]*\spush\b")
MAIN_RE = re.compile(r"\b(main|master)\b", re.IGNORECASE)
MERGE_RE = re.compile(r"\bgit\b[^|;&\n]*\smerge\b")
MERGE_BASE_RE = re.compile(r"\bmerge-base\b")
CHECKOUT_RE = re.compile(r"\bgit\b[^|;&\n]*\s(checkout|switch)\b")


PATH_RE = r'"([^"]+)"|\'([^\']+)\'|([^\s;&|]+)'


def resolve_path(path, cwd):
    # normalize a path pulled out of a command: expand ~, convert git-bash
    # style /c/Users/... to C:/Users/... on Windows, resolve relative to cwd
    path = os.path.expanduser(path)
    if os.name == "nt":
        m = re.match(r'^/([A-Za-z])(/.*)?$', path)
        if m:
            path = m.group(1).upper() + ":" + (m.group(2) or "/")
    if not os.path.isabs(path):
        path = os.path.join(cwd, path)
    return path


def command_cwd(cmd: str, cwd: str, match: re.Match) -> str:
    # directory the matched `git ...` command in cmd actually runs in: its
    # own `-C <path>`, else the last `cd <path>` before it, else cwd
    seg = cmd[match.start():match.end()]
    c_match = re.search(r'-C\s+(?:' + PATH_RE + r')', seg)
    if c_match:
        path = c_match.group(1) or c_match.group(2) or c_match.group(3)
        return resolve_path(path, cwd)
    cd_matches = list(re.finditer(r'\bcd\s+(?:' + PATH_RE + r')', cmd[:match.start()]))
    if cd_matches:
        cm = cd_matches[-1]
        path = cm.group(1) or cm.group(2) or cm.group(3)
        return resolve_path(path, cwd)
    return cwd


def git(*args, cwd=None):
    try:
        return subprocess.run(["git", *args], capture_output=True, text=True,
                              timeout=10, cwd=cwd).stdout.strip()
    except Exception:
        return ""


def deny(why):
    sys.stderr.write(
        f"Blocked by .claude/hooks/git-guard.py: {why}. The owner lands "
        "branches with tools/try.py --commit and pushes with GitHub "
        "Desktop. If the user explicitly asked for this command, ask them "
        "to run it themselves.\n")
    sys.exit(2)


def session_dir(transcript_path: str) -> str:
    p = os.path.normpath(transcript_path)
    if os.path.basename(os.path.dirname(p)) == "subagents":
        return os.path.dirname(os.path.dirname(p))
    return os.path.splitext(p)[0]


def foreign_paths(d: dict) -> list[str]:
    try:
        fp = os.path.join(session_dir(d["transcript_path"]), "foreign-paths.json")
        with open(fp, encoding="utf-8") as f:
            return json.load(f)
    except (KeyError, OSError, ValueError):
        return []


def add_targets(cmd: str) -> list[str]:
    targets = []
    for m in re.finditer(r"\bgit\s+add\b([^|;&\n]*)", cmd):
        try:
            tokens = shlex.split(m.group(1), posix=True)
        except ValueError:
            tokens = m.group(1).split()
        targets += [t for t in tokens if not t.startswith("-")]
    return targets


def normalize_target(target: str, cwd: str) -> str:
    path = resolve_path(target, cwd)
    if os.path.isabs(path):
        top = git("rev-parse", "--show-toplevel", cwd=cwd)
        if top:
            try:
                path = os.path.relpath(path, top)
            except ValueError:
                pass
    path = path.replace("\\", "/")
    if path.startswith("./"):
        path = path[2:]
    return path


def foreign_matches(cmd: str, cwd: str, d: dict) -> list[str]:
    foreign = foreign_paths(d)
    if not foreign:
        return []
    targets = [normalize_target(t, cwd) for t in add_targets(cmd)]
    matches = []
    for f in foreign:
        for t in targets:
            if f == t or f.startswith(t.rstrip("/") + "/") or fnmatch.fnmatch(f, t) or (f.endswith("/") and t.startswith(f)):
                matches.append(f)
                break
    return matches


def main():
    d = json.load(sys.stdin)
    cmd = (d.get("tool_input") or {}).get("command") or ""
    if "git" not in cmd and "gh" not in cmd:
        return
    for pat, why in BLOCK:
        if re.search(pat, cmd):
            sys.stderr.write(
                f"Blocked by .claude/hooks/git-guard.py: {why}. Another "
                "session may have uncommitted edits in this tree. Stage your "
                "own files by path (git add <file> ...) and commit those. If "
                "the user explicitly asked for this command, ask them to run "
                "it themselves.\n")
            sys.exit(2)

    matches = foreign_matches(cmd, d.get("cwd") or os.getcwd(), d)
    if matches:
        sys.stderr.write(
            f"Blocked by .claude/hooks/git-guard.py: {', '.join(matches)} "
            "already had uncommitted edits when this session started (the "
            "owner's or another session's). Stage only the files your specs "
            "changed, by path. If the user explicitly asked to commit them, "
            "ask them to run it themselves.\n")
        sys.exit(2)

    if GH_MERGE_RE.search(cmd):
        deny("only the owner merges")

    if BRANCH_DELETE_RE.search(cmd):
        deny("the owner deletes branches")

    if WORKTREE_REMOVE_RE.search(cmd):
        deny("the owner removes worktrees (archiving a session in the app does it)")

    if PUSH_RE.search(cmd):
        remote_ok = (os.environ.get("CLAUDE_CODE_REMOTE") == "true"
                     and not MAIN_RE.search(cmd))
        if not remote_ok:
            deny("only the owner pushes (GitHub Desktop)")

    if (MERGE_RE.search(cmd) and not MERGE_BASE_RE.search(cmd)
            and "--abort" not in cmd):
        cwd = d.get("cwd") or os.getcwd()
        m = MERGE_RE.search(cmd)
        mcwd = command_cwd(cmd, cwd, m)
        if not os.path.isdir(mcwd):
            mcwd = cwd
        if git("branch", "--show-current", cwd=mcwd) == "main":
            deny("never merge into main; tools/try.py --commit lands branches")

    m = CHECKOUT_RE.search(cmd)
    if m:
        cwd = d.get("cwd") or os.getcwd()
        wd = command_cwd(cmd, cwd, m)
        if not os.path.isdir(wd):
            wd = cwd
        common = git("rev-parse", "--path-format=absolute", "--git-common-dir", cwd=wd)
        top = git("rev-parse", "--show-toplevel", cwd=wd)
        main_checkout = (common and top
                          and os.path.normcase(os.path.abspath(os.path.dirname(common)))
                          == os.path.normcase(os.path.abspath(top)))
        if main_checkout and os.environ.get("CLAUDE_CODE_REMOTE") != "true":
            deny("the main checkout stays on main (GitHub Desktop and other "
                 "sessions use it); branch work belongs in a worktree session")

    # The note is computed before the command runs, so skip it when the
    # command stages files itself (the list would be stale).
    if re.search(r"\bgit\s+commit\b", cmd) and not re.search(r"\bgit\s+add\b", cmd):
        unstaged = git("diff", "--name-only")
        untracked = git("ls-files", "--others", "--exclude-standard")
        left = [l for l in (unstaged + "\n" + untracked).splitlines() if l]
        if left:
            note = ("Unstaged files staying out of this commit (foreign "
                    "edits unless you made them; if yours, stage them by "
                    "path first): " + ", ".join(left))
            print(json.dumps({"hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "additionalContext": note}}))


try:
    main()
except SystemExit:
    raise
except Exception:
    pass
