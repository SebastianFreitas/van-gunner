"""Try a session's branch locally, without touching the main checkout.

    py -3 tools/try.py                                 list session branches
    py -3 tools/try.py <branch> [project flags]        Try it
    py -3 tools/try.py <branch> --commit               land it
    py -3 tools/try.py main [project flags]            Try the main checkout as it is

Try checks the branch out (detached) into the sibling <repo>-try worktree and
launches it through the project's tools/try_project.py, which may define
setup(root), add_arguments(parser) and launch(tree, args, is_main) ->
(Popen | None, url | None). Without it, try only checks the branch out.
Commit is tools/try_commit.py.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import time
import webbrowser
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from try_commit import ROOT, TRY_DIR, ensure_tree, git, git_run, hook, land  # noqa: E402


def list_branches() -> None:
    git_run("fetch", "origin", "--prune")
    listing = git(
        "for-each-ref", "--sort=-committerdate",
        "refs/heads/claude", "refs/heads/worktree-*", "refs/remotes/origin/claude",
        "--format=%(refname:short)|%(committerdate:relative)|%(subject)",
        check=False,
    )
    lines = [line for line in listing.splitlines() if line]

    print("Session branches, newest first:")
    if not lines:
        print("No session branches (claude/*) here or on origin.")
    else:
        for line in lines:
            name, when, subject = line.split("|", 2)
            print(f"  {name:<44} {when:<16} {subject[:70]}")
    print()
    print("Try one: py -3 tools/try.py <branch>    Land it: py -3 tools/try.py <branch> --commit")


def resolve(name: str) -> tuple[str, str]:
    """Returns (branch, ref): ref is 'origin/<branch>' when the remote copy is
    the newest, else the local branch name. Exits with a listing if neither exists."""
    if name.startswith("origin/"):
        name = name[len("origin/"):]

    candidates = [name]
    if "/" not in name:
        candidates.append("claude/" + name)
        candidates.append("worktree-" + name)

    for c in candidates:
        local = git("rev-parse", "--verify", "--quiet", f"refs/heads/{c}", check=False) != ""
        git_run("fetch", "origin", c)
        remote = git("rev-parse", "--verify", "--quiet", f"refs/remotes/origin/{c}", check=False) != ""

        if not local and not remote:
            continue
        if local and not remote:
            return c, c
        if remote and not local:
            return c, f"origin/{c}"

        ahead = git_run("merge-base", "--is-ancestor", f"origin/{c}", c).returncode == 0
        if ahead:
            return c, c
        return c, f"origin/{c}"

    print(f"No branch {name}, locally or on origin.")
    list_branches()
    sys.exit(1)


def stop(proc: subprocess.Popen | None) -> None:
    if proc is None or proc.poll() is not None:
        return
    proc.terminate()
    try:
        proc.wait(timeout=10)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait()


def wait_for(proc: subprocess.Popen | None) -> None:
    """Block until proc exits; Ctrl+C stops it."""
    if proc is None:
        return
    try:
        proc.wait()
    except KeyboardInterrupt:
        stop(proc)
        print("Stopped.")


def prompt_loop(proc: subprocess.Popen | None, allow_commit: bool, on_commit) -> int:
    """Enter stops proc; "commit" (if allowed) stops it and returns on_commit()."""
    print(
        "Enter = stop."
        + ("  Type commit + Enter = squash it into main as one commit (nothing is pushed)."
           if allow_commit else "")
    )
    while True:
        try:
            ans = input("> ").strip().lower()
        except EOFError:
            # Nothing to read from (stdin at NUL reports isatty() on Windows): wait like the non-tty branch.
            wait_for(proc)
            return 0
        except KeyboardInterrupt:
            ans = ""
        if ans == "commit" and allow_commit:
            stop(proc)
            return on_commit()
        elif ans == "":
            stop(proc)
            print("Stopped.")
            return 0
        else:
            print("Type commit or press Enter." if allow_commit else "Press Enter to stop.")


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")  # branch subjects can hold non-ASCII

    setup = hook("setup")
    if setup:
        setup(ROOT)

    parser = argparse.ArgumentParser(description=(__doc__ or "").splitlines()[0])
    parser.add_argument("branch", nargs="?")
    parser.add_argument(
        "--commit", action="store_true",
        help="land the branch on local main as one commit; nothing is pushed",
    )
    parser.add_argument("--no-open", action="store_true", help="do not open the url in a browser")
    add_arguments = hook("add_arguments")
    if add_arguments:
        add_arguments(parser)
    args = parser.parse_args()

    if not args.branch:
        list_branches()
        return 0

    launch = hook("launch")

    if args.branch == "main":
        if args.commit:
            print("main is already main; nothing to commit.")
            return 1
        proc, url = launch(ROOT, args, True) if launch else (None, None)
        print(f"Trying main (this checkout)  {git('log', '-1', '--format=%s', 'main')}")
        print(f"Tree: {ROOT}")
        if url:
            print(f"Open: {url}")
            print("Ctrl+C stops it.")
            if not args.no_open:
                time.sleep(0.8)
                webbrowser.open(url)
        if proc is None:
            if not url:
                print("No launcher (tools/try_project.py launch); open the tree yourself.")
            return 0
        if sys.stdin.isatty():
            return prompt_loop(proc, False, None)
        wait_for(proc)
        return 0

    branch, ref = resolve(args.branch)
    if args.commit:
        return land(branch, ref, args)

    sha = git("rev-parse", "--short", ref)
    subject = git("log", "-1", "--format=%s", ref)

    ensure_tree(ref)

    proc, url = launch(TRY_DIR, args, False) if launch else (None, None)

    print(f"Trying {branch} @ {sha}  {subject}")
    print(f"Tree: {TRY_DIR}")
    if url:
        print(f"Open: {url}")
        print("Ctrl+C stops the server.")
    if proc is None and url is None:
        print("No launcher (tools/try_project.py launch); open the tree yourself.")

    if url and not args.no_open:
        time.sleep(0.8)
        webbrowser.open(url)

    if sys.stdin.isatty():
        return prompt_loop(proc, True, lambda: land(branch, ref, args))
    wait_for(proc)
    return 0


if __name__ == "__main__":
    sys.exit(main())
