"""Land a session branch on local main as one verified commit (the owner's Commit).

Called by tools/try.py (`--commit`, or typing `commit` at its prompt).

1. Refuse unless the main checkout is on main, has no merge, rebase or
   cherry-pick in progress, and isn't behind origin/main; and refuse before
   any verification when the owner's uncommitted edits touch files the
   branch changes.
2. Build the squash without touching the main checkout's files:
   `git merge-tree --write-tree` of main and the branch, then
   `git commit-tree` on main. Conflicts stop here, except a conflict
   limited to docs/PROJECT_MAP.md, which step 3 regenerates.
3. Check the result out in the try checkout (../van-gunner-try),
   regenerate docs/PROJECT_MAP.md there (folding it into the commit when
   it changes) and run tools/check.py; tools/smoke.py too when main moved
   since the branch was cut, or with --smoke. Any failure: nothing lands.
4. `git merge --ff-only` in the main checkout. The owner's uncommitted
   edits stay; git refuses, and nothing lands, only when the branch
   changes one of those files.
5. Merge main back into the session's worktree branch when it is local
   and clean, so its next round starts from this commit.

Never pushes, never deletes a branch, never runs Godot in the main checkout
(the owner's editor may be open there).
"""

from __future__ import annotations

import pathlib
import subprocess
import sys

from godot_env import main_checkout, seed_import_cache

HERE = pathlib.Path(__file__).resolve().parent.parent
ROOT = main_checkout(HERE) or HERE  # the main checkout even when this copy of the tool lives in a worktree
TRY_DIR = ROOT.parent / (ROOT.name + "-try")
MAP = "docs/PROJECT_MAP.md"
BASELINES = ("tools/smoke/fingerprint.baseline.txt", "tools/scene_dump/van.baseline.txt")


def git_run(*args: str, cwd: pathlib.Path = ROOT, stdin: str | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args], cwd=cwd, input=stdin, capture_output=True, text=True,
        encoding="utf-8", errors="replace",
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
                f"Could not check {ref} out in {TRY_DIR}. Close the game or editor "
                "running from there and run this again. Nothing changed."
            )
            sys.exit(1)
        git("clean", "-fd", cwd=TRY_DIR, check=False)  # keeps the ignored .godot/ and override.cfg
    else:
        print(f"{TRY_DIR} exists and is not a git worktree; move it away and run this again.")
        sys.exit(1)
    seed_import_cache(TRY_DIR)


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


def squash_tree(ref: str) -> str:
    r = git_run("merge-tree", "--write-tree", "--name-only", "--no-messages", "main", ref)
    lines = [line for line in r.stdout.splitlines() if line]
    if r.returncode not in (0, 1) or not lines:
        print(r.stderr, file=sys.stderr)
        print("git merge-tree failed (it needs git 2.38 or later). Nothing changed.")
        sys.exit(1)

    tree, conflicts = lines[0], lines[1:]
    if r.returncode == 1:
        blocking = [c for c in conflicts if c != MAP]
        if blocking:
            print("Conflicts with main, nothing changed:")
            for c in blocking:
                print("  " + c)
            if any(c in BASELINES for c in blocking):
                print(
                    "Both sides blessed a baseline. In that session, ask Claude to merge "
                    "main into its branch, re-run the smoke test or scene dump, bless only "
                    "if the change is meant to alter it, and commit; then run this again."
                )
            else:
                print(
                    "In that session, ask Claude to merge main into its branch and "
                    "resolve, then run this again."
                )
            sys.exit(1)
        print(f"   {MAP} conflicts; it is regenerated on the combined tree")

    return tree


def dirty_overlap(tree: str) -> list[str]:
    """Uncommitted or untracked paths in the main checkout that the squash would
    change: git would refuse the fast-forward over them after the whole
    verification, so land() checks first."""
    changed = set(line for line in git("diff", "--name-only", "main", tree).splitlines() if line)

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
    if len(commits) == 1:
        msg = git("log", "-1", "--format=%B", commits[0])
    else:
        subject = git("log", "-1", "--format=%s", commits[-1])
        titles = git("log", "--reverse", "--no-merges", "--format=- %s", f"{base}..{ref}")
        trailer_lines = git(
            "log", "--format=%(trailers:key=Co-Authored-By,valueonly)", f"{base}..{ref}"
        ).splitlines()
        trailers = []
        for t in trailer_lines:
            if t and t not in trailers:
                trailers.append(t)
        msg = subject + "\n\nSquashed from " + branch + ":\n" + titles
        if trailers:
            msg += "\n\n" + "\n".join("Co-Authored-By: " + t for t in trailers)

    return msg.splitlines()[0], msg.strip() + "\n"


def verify(sha: str, run_smoke: bool, why: str) -> str | None:
    ensure_tree(sha)

    print(f"== {MAP} on the combined tree")
    r = subprocess.run(
        [sys.executable, "tools/gen_context.py"], cwd=TRY_DIR,
        capture_output=True, text=True, encoding="utf-8", errors="replace",
    )
    if r.returncode != 0:
        for line in (r.stdout + r.stderr).splitlines()[-10:]:
            print("   " + line)
        print("Nothing landed: tools/gen_context.py failed.")
        return None

    if git("status", "--porcelain", "--", MAP, cwd=TRY_DIR, check=False):
        git("add", "--", MAP, cwd=TRY_DIR)
        git("commit", "--amend", "--no-edit", "-q", cwd=TRY_DIR)
        sha = git("rev-parse", "HEAD", cwd=TRY_DIR)
        print("   regenerated and folded into the commit")
    else:
        print("   unchanged")

    tools = ["tools/check.py"] + (["tools/smoke.py"] if run_smoke else [])
    if run_smoke:
        print(f"   the smoke test runs too: {why}")

    for tool in tools:
        print(f"== {tool} on the combined tree")
        r = subprocess.run(
            [sys.executable, tool], cwd=TRY_DIR,
            capture_output=True, text=True, encoding="utf-8", errors="replace",
        )
        output_lines = (r.stdout + r.stderr).splitlines()
        if r.returncode != 0:
            for line in output_lines[-15:]:
                print("   " + line)
            print(
                f"Nothing landed: {tool} fails on main plus this branch. In that session, "
                "ask Claude to merge main into its branch, fix it and commit; then run "
                "this again."
            )
            return None
        print("   " + (output_lines[-1] if output_lines else "ok"))

    return sha


def sync_worktree(branch: str) -> None:
    wt = worktree_of(branch)
    if wt is None:
        return
    if git("status", "--porcelain", cwd=wt, check=False) == "":
        r = git_run("merge", "-q", "--no-edit", "main", cwd=wt)
        if r.returncode != 0:
            conflicts = [
                p for p in git("diff", "--name-only", "--diff-filter=U", cwd=wt, check=False).splitlines() if p
            ]
            if conflicts == [MAP]:
                # main's map was regenerated on the combined tree when the branch landed, so it wins.
                git_run("checkout", "--theirs", "--", MAP, cwd=wt)
                git_run("add", "--", MAP, cwd=wt)
                done = git_run("commit", "--no-edit", "-q", cwd=wt)
                if done.returncode == 0:
                    print(
                        f"Merged main back into {branch} (taking main's {MAP}), so the next round "
                        "there starts from this commit."
                    )
                    return
            git_run("merge", "--abort", cwd=wt)
            print(
                f"Could not merge main back into {branch} ({wt}); ask Claude in that "
                "session to merge main before its next round."
            )
        else:
            print(f"Merged main back into {branch}, so the next round there starts from this commit.")
    else:
        print(
            f"{branch} was not synced (uncommitted files in {wt}); ask Claude there to "
            "merge main before its next round."
        )


def land(branch: str, ref: str, smoke: bool) -> int:
    main_sha = preflight()

    base = git("merge-base", "main", ref)
    if git("rev-list", "--count", "--no-merges", f"{base}..{ref}") == "0":
        print(f"{branch} has nothing that main lacks. Nothing to commit.")
        return 0

    tree = squash_tree(ref)
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

    subject, msg = squash_message(branch, base, ref)
    sha = git("commit-tree", tree, "-p", main_sha, "-F", "-", stdin=msg)

    main_moved = base != main_sha
    why = "main moved since this branch was cut" if main_moved else "--smoke was given"
    final = verify(sha, smoke or main_moved, why)
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

    sync_worktree(branch)
    print(f"Committed {git('rev-parse', '--short', 'HEAD')} on main: {subject}")
    print(
        "Nothing was pushed. Review it in GitHub Desktop (History), then Push origin. "
        "To take it back before pushing: History, right-click it, Undo commit."
    )
    print("If the Godot editor is open on this project, let it reimport the changed files.")
    return 0
