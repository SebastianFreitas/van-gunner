"""Land a session branch on local main as one verified commit (the owner's Commit).

Called by tools/try.py (`--commit`, or typing `commit` at its prompt).

1. Refuse unless the main checkout is on main, has no merge, rebase or
   cherry-pick in progress, and isn't behind origin/main; and refuse before
   any verification when the owner's uncommitted edits touch files the
   branch changes.
2. Build the squash without touching the main checkout's files:
   `git merge-tree --write-tree` of main and the branch, then
   `git commit-tree` on main. The commit has one parent (main), so the
   branch's own commits and merges never reach main's history. Conflicts
   stop here, except a conflict limited to the project's REGENERATED
   paths, which step 3 rebuilds.
3. Check the result out in the try checkout (../<project>-try), let the
   project rebuild what it generates (before_commit; whatever it changes
   is folded into the commit) and run the project's checks (verify).
   Any failure: nothing lands.
4. `git merge --ff-only` in the main checkout. The owner's uncommitted
   edits stay; git refuses, and nothing lands, only when the branch
   changes one of those files.
5. Move the session's branch to main when its worktree is clean and has
   nothing newer than what landed (`git reset --keep main`), so its next
   round starts from this commit and lists only new work.
6. Push main to origin. The app cuts new worktrees from origin/main, so an
   unpushed main means every new session starts without this commit
   (owner, 2026-10-01). A failed push leaves the commit on local main and
   says so; the owner pushes it from GitHub Desktop.

The project plugs in through the optional tools/try_project.py, loaded from
the main checkout. This module uses:
  REGENERATED   tuple of repo paths rebuilt on the combined tree; a merge
                conflict limited to them is not a conflict, and the merge
                back into the session's branch takes main's copy.
  BASELINES     tuple of recorded baseline paths; a real conflict in one
                gets a hint on how to re-record it.
  prepare_tree(try_dir)
                run after the try checkout is set to a commit (seed caches).
  before_commit(try_dir) -> bool
                rebuild generated files in the try checkout; False stops.
  verify(try_dir, main_moved, args) -> bool
                the project's checks on the combined tree; False stops.
                main_moved is True when main gained commits since the
                branch was cut; args is try.py's parsed command line.
  after_land(root)
                run in the main checkout after the commit landed.

Pushes only main, only after it landed; never deletes a branch, never runs project code in the main
checkout except after_land (the owner's editor may be open there).
"""

from __future__ import annotations

import importlib.util
import pathlib
import subprocess
import sys


def _main_root() -> pathlib.Path:
    here = pathlib.Path(__file__).resolve().parent.parent
    r = subprocess.run(["git", "rev-parse", "--git-common-dir"], cwd=here, capture_output=True, text=True)
    if r.returncode != 0:
        return here
    return (here / r.stdout.strip()).resolve().parent  # the main checkout even from a worktree


ROOT = _main_root()
TRY_DIR = ROOT.parent / (ROOT.name + "-try")

_project = None
_project_loaded = False


def load_project():
    """tools/try_project.py of the main checkout as a module, else None; loaded once."""
    global _project, _project_loaded
    if not _project_loaded:
        _project_loaded = True
        path = ROOT / "tools" / "try_project.py"
        if path.exists():
            spec = importlib.util.spec_from_file_location("try_project", path)
            _project = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(_project)
    return _project


def hook(name: str):
    """The project's function `name`, or None when it defines none."""
    project = load_project()
    return getattr(project, name, None) if project else None


def project_const(name: str, default):
    """The project's module attribute `name`, or `default`."""
    project = load_project()
    return getattr(project, name, default) if project else default


def git_run(*args: str, cwd: pathlib.Path = ROOT, stdin: str | None = None) -> subprocess.CompletedProcess[str]:
    if stdin is None:
        return subprocess.run(
            ["git", *args], cwd=cwd, capture_output=True, text=True,
            encoding="utf-8", errors="replace",
        )
    # Bytes in, so Windows text mode does not turn the message's \n into \r\n.
    raw = subprocess.run(
        ["git", *args], cwd=cwd, input=stdin.encode("utf-8"), capture_output=True,
    )
    return subprocess.CompletedProcess(
        raw.args, raw.returncode,
        raw.stdout.decode("utf-8", errors="replace"), raw.stderr.decode("utf-8", errors="replace"),
    )


def git(*args: str, cwd: pathlib.Path = ROOT, check: bool = True, stdin: str | None = None) -> str:
    result = git_run(*args, cwd=cwd, stdin=stdin)
    if check and result.returncode != 0:
        print(result.stderr, file=sys.stderr)
        sys.exit(1)
    return result.stdout.strip()


def worktree_of(branch: str) -> pathlib.Path | None:
    """Path of the worktree that has `branch` checked out, else None."""
    listing = git("worktree", "list", "--porcelain", check=False)
    for entry in listing.split("\n\n"):
        path = None
        for line in entry.splitlines():
            if line.startswith("worktree "):
                path = line[len("worktree "):]
            elif line == f"branch refs/heads/{branch}":
                return pathlib.Path(path)
    return None


def ensure_tree(ref: str) -> None:
    if not TRY_DIR.exists():
        git("worktree", "prune", check=False)
        git("worktree", "add", "--detach", str(TRY_DIR), ref)
    elif (TRY_DIR / ".git").exists():
        r = git_run("checkout", "--detach", "--force", ref, cwd=TRY_DIR)
        if r.returncode != 0:
            print(r.stderr, file=sys.stderr)
            print(
                f"Could not check {ref} out in {TRY_DIR}. Close whatever runs from "
                "there and run this again. Nothing changed."
            )
            sys.exit(1)
        git("clean", "-fd", cwd=TRY_DIR, check=False)  # ignored files survive
    else:
        print(f"{TRY_DIR} exists and is not a git worktree; move it away and run this again.")
        sys.exit(1)
    prepare = hook("prepare_tree")
    if prepare:
        prepare(TRY_DIR)


def preflight() -> str:
    current = git("rev-parse", "--abbrev-ref", "HEAD")
    if current != "main":
        print(
            f"The main checkout ({ROOT}) is on {current}, not main. Switch to main in "
            "GitHub Desktop and run this again. Nothing changed."
        )
        sys.exit(1)

    git_dir = pathlib.Path(git("rev-parse", "--absolute-git-dir"))
    mid_operation = (
        (git_dir / "MERGE_HEAD").exists()
        or (git_dir / "rebase-merge").exists()
        or (git_dir / "rebase-apply").exists()
        or (git_dir / "CHERRY_PICK_HEAD").exists()
    )
    if mid_operation:
        print(
            "The main checkout is in the middle of a merge, rebase or cherry-pick; "
            "finish or abort it in GitHub Desktop first. Nothing changed."
        )
        sys.exit(1)

    git_run("fetch", "origin", "main")
    if git("rev-parse", "--verify", "--quiet", "refs/remotes/origin/main", check=False):
        if git_run("merge-base", "--is-ancestor", "origin/main", "main").returncode != 0:
            print(
                "origin/main has commits your main lacks. Pull (Fetch origin, then Pull) "
                "in GitHub Desktop first, then run this again. Nothing changed."
            )
            sys.exit(1)

    return git("rev-parse", "main")


def squash_tree(ref: str) -> tuple[str, list[str]]:
    """The squashed tree and the REGENERATED paths that conflicted and were let through."""
    r = git_run("merge-tree", "--write-tree", "--name-only", "--no-messages", "main", ref)
    lines = [line for line in r.stdout.splitlines() if line]
    if r.returncode not in (0, 1) or not lines:
        print(r.stderr, file=sys.stderr)
        print("git merge-tree failed (it needs git 2.38 or later). Nothing changed.")
        sys.exit(1)

    tree, conflicts = lines[0], lines[1:]
    let_through: list[str] = []
    if r.returncode == 1:
        regenerated = project_const("REGENERATED", ())
        baselines = project_const("BASELINES", ())
        blocking = [c for c in conflicts if c not in regenerated]
        if blocking:
            print("Conflicts with main, nothing changed:")
            for c in blocking:
                print("  " + c)
            if any(c in baselines for c in blocking):
                print(
                    "Both sides recorded a baseline. In that session, ask Claude to merge "
                    "main into its branch, re-run the tool that writes it and re-record only "
                    "if the change is meant to alter it, and commit; then run this again."
                )
            else:
                print(
                    "In that session, ask Claude to merge main into its branch and "
                    "resolve, then run this again."
                )
            sys.exit(1)
        if conflicts and not hook("before_commit"):
            print(
                f"Conflicts in {', '.join(conflicts)}, which the project regenerates, but "
                "tools/try_project.py has no before_commit; nothing changed."
            )
            sys.exit(1)
        for c in conflicts:
            print(f"   {c} conflicts; it is regenerated on the combined tree")
        let_through = conflicts

    return tree, let_through


def dirty_overlap(tree: str) -> list[str]:
    """Uncommitted or untracked paths in the main checkout that the squash would
    change: git would refuse the fast-forward over them after the whole
    verification, so land() checks first."""
    changed = set(line for line in git("diff", "--name-only", "--no-renames", "main", tree).splitlines() if line)

    status = git_run("status", "--porcelain", "--untracked-files=all").stdout
    dirty: set[str] = set()
    for line in status.splitlines():
        if not line:
            continue
        path = line[3:]
        if " -> " in path:
            for side in path.split(" -> "):
                dirty.add(side.strip('"'))
        else:
            dirty.add(path.strip('"'))

    return sorted(changed & dirty)


def squash_message(branch: str, base: str, ref: str) -> tuple[str, str]:
    commits = git("rev-list", "--reverse", "--no-merges", f"{base}..{ref}").splitlines()
    tip_msg = git("log", "-1", "--format=%B", commits[-1])
    msg = "\n".join(l for l in tip_msg.splitlines() if not l.startswith("Co-Authored-By:")).rstrip()
    subjects = []
    for s in git("log", "--reverse", "--no-merges", "--format=%s", f"{base}..{ref}").splitlines():
        if s not in subjects:
            subjects.append(s)
    msg += "\n\nSquashed from " + branch + ":\n" + "\n".join("- " + s for s in subjects)
    trailers = []
    for t in git(
        "log", "--format=%(trailers:key=Co-Authored-By,valueonly)", f"{base}..{ref}"
    ).splitlines():
        if t and t not in trailers:
            trailers.append(t)
    if trailers:
        msg += "\n\n" + "\n".join("Co-Authored-By: " + t for t in trailers)

    return msg.splitlines()[0], msg.strip() + "\n"


def verify(sha: str, main_moved: bool, args, let_through: list[str]) -> str | None:
    ensure_tree(sha)

    before_commit = hook("before_commit")
    if before_commit:
        print("== tools/try_project.py before_commit on the combined tree")
        if before_commit(TRY_DIR) is False:
            print("Nothing landed: tools/try_project.py before_commit failed.")
            return None

        for path in let_through:
            f = TRY_DIR / path
            if f.exists() and any(
                line.startswith(("<<<<<<< ", ">>>>>>> "))
                for line in f.read_text(encoding="utf-8", errors="replace").splitlines()
            ):
                print(f"Nothing landed: {path} still has conflict markers after before_commit.")
                return None

        changed = git("status", "--porcelain", "--untracked-files=no", cwd=TRY_DIR, check=False)
        if changed:
            git("add", "-u", cwd=TRY_DIR)
            git("commit", "--amend", "--no-edit", "-q", cwd=TRY_DIR)
            sha = git("rev-parse", "HEAD", cwd=TRY_DIR)
            print("   regenerated and folded into the commit:")
            for line in changed.splitlines():
                print("     " + line.split(None, 1)[-1])  # git() strips the first line's leading space
        else:
            print("   unchanged")

    check = hook("verify")
    if check:
        print("== the project's checks on the combined tree")
        if check(TRY_DIR, main_moved, args) is False:
            print("Nothing landed: the project's checks failed on the combined tree.")
            return None

    return sha


def sync_worktree(branch: str, landed_sha: str) -> None:
    wt = worktree_of(branch)
    if wt is None:
        tip = git("rev-parse", "--verify", "-q", f"refs/heads/{branch}", check=False)
        if tip == landed_sha:
            git_run("branch", "-f", branch, "main")
        return
    if git("status", "--porcelain", cwd=wt, check=False) != "":
        print(
            f"{branch} was not synced (uncommitted files in {wt}); ask Claude there to "
            "merge main before its next round."
        )
    elif git("rev-parse", "HEAD", cwd=wt, check=False) == landed_sha:
        r = git_run("reset", "-q", "--keep", "main", cwd=wt)
        if r.returncode == 0:
            print(f"Moved {branch} to main, so the next round there starts from this commit.")
        else:
            print(r.stderr.strip(), file=sys.stderr)
            print(
                f"Could not move {branch} to main ({wt}); ask Claude in that session to "
                "run git merge main before its next round."
            )
    else:
        print(
            f"{branch} has commits newer than what landed, so it was left as is; "
            "they land with its next Commit."
        )


def push_main() -> None:
    r = git_run("push", "origin", "main")
    if r.returncode == 0:
        print(
            "Pushed main to origin, so new sessions start from this commit. To take it "
            "back: GitHub Desktop, History, right-click it, Revert changes in commit."
        )
    else:
        print(r.stderr.strip(), file=sys.stderr)
        print(
            "The commit is on local main but the push failed. Push origin in GitHub "
            "Desktop: until then new sessions start from origin/main without it."
        )


def land(branch: str, ref: str, args) -> int:
    main_sha = preflight()

    base = git("merge-base", "main", ref)
    if git("rev-list", "--count", "--no-merges", f"{base}..{ref}") == "0":
        print(f"{branch} has nothing that main lacks. Nothing to commit.")
        return 0

    tree, let_through = squash_tree(ref)
    if tree == git("rev-parse", "main^{tree}"):
        print(f"{branch} adds nothing that main lacks (its changes are already on main). Nothing to commit.")
        return 0

    overlap = dirty_overlap(tree)
    if overlap:
        print("You have uncommitted edits to files this branch changes, nothing changed:")
        for path in overlap:
            print("  " + path)
        print("Commit or discard them in GitHub Desktop, then run this again.")
        return 1

    ref_sha = git("rev-parse", ref)
    subject, msg = squash_message(branch, base, ref)
    sha = git("commit-tree", tree, "-p", main_sha, "-F", "-", stdin=msg)

    main_moved = base != main_sha
    final = verify(sha, main_moved, args, let_through)
    if final is None:
        return 1

    r = git_run("merge", "--ff-only", "-q", final)
    if r.returncode != 0:
        print(r.stderr, file=sys.stderr)
        print(
            "Nothing landed: git refused to fast-forward main. If it names files, you "
            "have uncommitted edits to files this branch changes: commit or discard them "
            "in GitHub Desktop, then run this again. If main moved while this ran, run it "
            "again."
        )
        return 1

    sync_worktree(branch, ref_sha)
    print(f"Committed {git('rev-parse', '--short', 'HEAD')} on main: {subject}")
    push_main()

    after_land = hook("after_land")
    if after_land:
        after_land(ROOT)

    cleanup = ROOT / "tools" / "cleanup.py"
    if cleanup.exists():
        subprocess.run([sys.executable, str(cleanup), "--quiet", "--keep", branch], cwd=ROOT)
    print(
        f"LANDED: {branch} is done. Its session can be archived; a follow-up "
        "there commits on the same branch and lands again."
    )
    return 0
