"""Git guard (PreToolUse on Bash / PowerShell): other sessions edit this
tree at the same time, so blanket git commands are blocked (exit 2, the
reason goes back to the session). A plain `git commit` passes through (the
normal permission prompt still applies) and gets a note listing the
unstaged files that are staying out of it; paths matching the project's
`quiet_dirty` globs (.claude/project/file-guard.json) are counted in one
item instead of listed.

Also enforces the owner-only path to `main`/origin: the owner lands
branches with `py -3 tools/try.py <branch> --commit`, which pushes main
once it landed. Sessions never push (except a cloud session pushing its
own non-main branch), never merge into `main`, never delete a branch or
remove a worktree (tools/cleanup.py does both once a branch has landed),
and never run `gh pr merge`.

`tools/try.py <branch> --commit` (landing a branch on main) runs only on
the owner's OK: the owner's latest prompt in the transcript must say
merge or land (and not "don't merge"). Subagents and unattended
(`AUTOPLAN=1`) sessions are always refused; the owner lands those runs.

In the main checkout (shared mode), `git checkout` / `git switch` are also
refused: the owner's GitHub Desktop and other sessions rely on it staying
on `main`.

`git add` naming a path listed in `<session dir>/foreign-paths.json`
(written by session-start.py in shared mode: paths already uncommitted
when the session started) is refused too, so a session can't sweep up
another session's edits by path even when it avoids the blanket patterns
below.

Every rule below matches against the command with the inside of quoted
strings masked, so a commit message or search string never trips a rule.

Never blocks on its own failure: any error exits 0.
"""
import fnmatch
import json
import os
import re
import shlex
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from guard_config import load_config, matches_any, quiet_globs, quiet_line  # noqa: E402

QUOTED = re.compile(r'"[^"]*"|\'[^\']*\'')


def mask_quotes(cmd: str) -> str:
    """The command with the inside of every quoted string replaced by x's of the
    same length, so rules never match message or search text and match
    positions still line up with the original command."""
    return QUOTED.sub(lambda m: m.group(0)[0] + "x" * (len(m.group(0)) - 2) + m.group(0)[-1], cmd)


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
MERGE_RE = re.compile(r"\bgit\b[^|;&\n]*\smerge\b")
MERGE_BASE_RE = re.compile(r"\bmerge-base\b")
CHECKOUT_RE = re.compile(r"\bgit\b[^|;&\n]*\s(checkout|switch)\b")

TARGET_RE = re.compile(r"^\+?(?:[^:\s]*:)?(?:refs/heads/)?(?:main|master)$")


def pushes_main(bare: str, m: re.Match) -> bool:
    """True when the push names main or master as a target (main, HEAD:main,
    +main, refs/heads/main), not merely a branch whose name contains main."""
    tail = re.split(r"[|;&\n]", bare[m.end():], maxsplit=1)[0]
    for tok in tail.split():
        if tok.startswith("-"):
            continue
        if TARGET_RE.match(tok):
            return True
    return False


LAND_RE = re.compile(r"\btry\.py\b[^|;&\n]*\s--commit\b")
LAND_OK_RE = re.compile(r"\b(merge|land)\b|--commit", re.I)
LAND_NO_RE = re.compile(
    r"\b(don'?t|do not|not yet|never|no|wait|hold)\b[^.\n]{0,25}\b(merge|land)", re.I)


def last_owner_prompt(transcript_path: str) -> str:
    """Text of the newest human prompt in the transcript (not a tool result,
    not an injected meta entry), or "" when none is found."""
    try:
        with open(transcript_path, "rb") as f:
            f.seek(0, 2)
            size = f.tell()
            f.seek(max(0, size - 4_000_000))
            lines = f.read().decode("utf-8", "replace").splitlines()
    except OSError:
        return ""
    for line in reversed(lines):
        try:
            e = json.loads(line)
        except ValueError:
            continue
        if e.get("type") != "user" or e.get("isMeta"):
            continue
        content = (e.get("message") or {}).get("content")
        if isinstance(content, str):
            text = content
        elif isinstance(content, list):
            if any(isinstance(b, dict) and b.get("type") == "tool_result" for b in content):
                continue
            text = " ".join(b.get("text", "") for b in content
                            if isinstance(b, dict) and b.get("type") == "text")
        else:
            continue
        # drop injected reminders so only the owner's own words count
        text = re.sub(r"<system-reminder>.*?</system-reminder>", " ", text, flags=re.S)
        if text.strip():
            return text
    return ""


def landing_refusal(d: dict) -> str:
    """Why this session may not run try.py --commit now, or "" when the owner OK'd it."""
    if os.environ.get("AUTOPLAN") == "1":
        return ("an unattended plan run never lands; the owner lands the "
                "finished branch after the Stage done report")
    tp = d.get("transcript_path") or ""
    if os.path.basename(os.path.dirname(os.path.normpath(tp))) == "subagents":
        return "a subagent never lands a branch"
    said = last_owner_prompt(tp)
    if LAND_OK_RE.search(said) and not LAND_NO_RE.search(said):
        return ""
    return ("landing on main waits for the owner's OK: their latest message "
            "must say merge or land. Commit on the branch, end with the "
            "Commit command in the report, and let the owner run it or reply "
            "\"merge it\"")


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
        "branches with tools/try.py --commit, which pushes main itself. "
        "If the user explicitly asked for this command, ask them to run "
        "it themselves.\n")
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
    if "git" not in cmd and "gh" not in cmd and "try.py" not in cmd:
        return
    bare = mask_quotes(cmd)
    if LAND_RE.search(bare):
        why = landing_refusal(d)
        if why:
            sys.stderr.write(f"Blocked by .claude/hooks/git-guard.py: {why}.\n")
            sys.exit(2)
    for pat, why in BLOCK:
        if re.search(pat, bare):
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

    if GH_MERGE_RE.search(bare):
        deny("only the owner merges")

    if BRANCH_DELETE_RE.search(bare):
        deny("branches are deleted only by tools/cleanup.py (landed on main and idle); run that instead")

    if WORKTREE_REMOVE_RE.search(bare):
        deny("worktrees are removed only by tools/cleanup.py (landed on main and idle) or by archiving the session in the app")

    m = PUSH_RE.search(bare)
    if m:
        remote_ok = (os.environ.get("CLAUDE_CODE_REMOTE") == "true"
                     and not pushes_main(bare, m))
        if not remote_ok:
            deny("only the owner pushes (GitHub Desktop)")

    if (MERGE_RE.search(bare) and not MERGE_BASE_RE.search(bare)
            and "--abort" not in bare):
        cwd = d.get("cwd") or os.getcwd()
        m = MERGE_RE.search(bare)
        mcwd = command_cwd(cmd, cwd, m)
        if not os.path.isdir(mcwd):
            mcwd = cwd
        if git("branch", "--show-current", cwd=mcwd) == "main":
            deny("never merge into main; tools/try.py --commit lands branches")

    m = CHECKOUT_RE.search(bare)
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
    if re.search(r"\bgit\s+commit\b", bare) and not re.search(r"\bgit\s+add\b", bare):
        unstaged = git("diff", "--name-only")
        untracked = git("ls-files", "--others", "--exclude-standard")
        left = [l for l in (unstaged + "\n" + untracked).splitlines() if l]
        # Paths matching quiet_dirty are counted, not listed.
        top = git("rev-parse", "--show-toplevel")
        quiet = quiet_globs(load_config(top)) if top else []
        shown = [l for l in left if not (quiet and matches_any(l, quiet))]
        if len(shown) < len(left):
            shown.append(quiet_line(len(left) - len(shown), quiet))
        if left:
            note = ("Unstaged files staying out of this commit (foreign "
                    "edits unless you made them; if yours, stage them by "
                    "path first): " + ", ".join(shown))
            print(json.dumps({"hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "additionalContext": note}}))


try:
    main()
except SystemExit:
    raise
except Exception:
    pass
