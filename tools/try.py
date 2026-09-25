"""Play a session's branch, or land it on local main: the owner's Try and Commit.

    py -3 tools/try.py                          list session branches
    py -3 tools/try.py <branch>                 play it
    py -3 tools/try.py <branch> --editor        open it in the Godot editor
    py -3 tools/try.py <branch> --scene res://path.tscn
    py -3 tools/try.py <branch> --commit        land it (tools/try_commit.py)
    py -3 tools/try.py main                     play the main checkout as it is

Playing checks the branch out (detached) into a sibling worktree,
../van-gunner-try, whose .godot/ import cache is seeded from the main
checkout the first time and stays warm, runs an import scan and launches
the game with the console build, so its errors print here and are counted
when the window closes (the full log goes to .godot/try-last.log there).
user:// goes to a separate van-gunner-try profile through a gitignored
override.cfg, so a branch never touches the owner's real saves or
schematic (--real-saves skips that). Typing `commit` at the prompt lands
the branch.

`main` plays the main checkout itself with the real profile, without an
import scan (the owner's editor may be open on it).
"""

from __future__ import annotations

import argparse
import pathlib
import re
import subprocess
import sys
import threading

from godot_env import godot_exe, project_lock
from try_commit import ROOT, TRY_DIR, ensure_tree, git, git_run, land

FAILURE = re.compile(r"SCRIPT ERROR|Parse Error|ERROR:")
ANSI = re.compile(r"\x1b\[[0-9;]*m")
OVERRIDE = """; Written by tools/try.py for this checkout only (gitignored): user:// goes
; to a separate profile, so a branch never touches the real saves or schematic.
[application]

config/use_custom_user_dir=true
config/custom_user_dir_name="van-gunner-try"
"""


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
    print("Play one: py -3 tools/try.py <branch>    Land it: py -3 tools/try.py <branch> --commit")


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


def write_override(tree: pathlib.Path, real_saves: bool) -> None:
    path = tree / "override.cfg"
    if real_saves:
        path.unlink(missing_ok=True)
    else:
        path.write_text(OVERRIDE, encoding="utf-8", newline="\n")


def import_scan(tree: pathlib.Path, exe: str) -> None:
    print("== import scan (re-imports only what changed since the last try)")
    with project_lock(tree):
        try:
            r = subprocess.run(
                [exe, "--headless", "--path", str(tree), "--import"],
                cwd=tree, capture_output=True, text=True, encoding="utf-8", errors="replace",
                timeout=900,
            )
        except subprocess.TimeoutExpired:
            print("   timed out after 900 s")
            return
    lines = [ANSI.sub("", line.rstrip()) for line in (r.stdout + r.stderr).splitlines()]
    hits = [line for line in lines if FAILURE.search(line)]
    for hit in hits[:10]:
        print("   " + hit)
    print(f"   {len(hits)} error line(s)")


class Game:
    """The running game or editor; tails the game's output into a log, echoing and
    counting error lines."""

    def __init__(self, exe: str, tree: pathlib.Path, scene: str | None, editor: bool) -> None:
        self.errors: list[str] = []
        self.log_path: pathlib.Path | None = None
        self.thread: threading.Thread | None = None
        self.summarised = False

        if editor:
            args = [exe, "--editor", "--path", str(tree)]
            self.proc = subprocess.Popen(args, cwd=tree, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        else:
            args = [exe, "--path", str(tree)] + ([scene] if scene else [])
            self.log_path = tree / ".godot" / "try-last.log"
            self.log_path.parent.mkdir(parents=True, exist_ok=True)
            self.proc = subprocess.Popen(
                args, cwd=tree, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                text=True, encoding="utf-8", errors="replace", bufsize=1,
            )
            self.thread = threading.Thread(target=self._pump, daemon=True)
            self.thread.start()

    def _pump(self) -> None:
        with open(self.log_path, "w", encoding="utf-8", newline="\n") as log:
            for line in self.proc.stdout:
                log.write(line)
                clean = ANSI.sub("", line)
                if FAILURE.search(clean):
                    self.errors.append(clean)
                    print("   " + line.rstrip())
        self.summary()

    def summary(self) -> None:
        if self.summarised:
            return
        self.summarised = True
        if self.log_path is not None:
            print(f"\nGame closed: {len(self.errors)} error line(s). Full log: {self.log_path}")

    def stop(self) -> None:
        if self.proc.poll() is None:
            self.proc.terminate()
            try:
                self.proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                self.proc.kill()
        if self.thread is not None:
            self.thread.join(timeout=5)
        self.summary()

    def wait(self) -> None:
        self.proc.wait()
        if self.thread is not None:
            self.thread.join(timeout=5)
        self.summary()


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")  # game logs and subjects hold non-ASCII
    parser = argparse.ArgumentParser(description=(__doc__ or "").splitlines()[0])
    parser.add_argument("branch", nargs="?")
    parser.add_argument(
        "--commit", action="store_true",
        help="land the branch on local main as one verified commit; nothing is pushed",
    )
    parser.add_argument(
        "--smoke", action="store_true",
        help="with --commit: always run the smoke test on the combined tree",
    )
    parser.add_argument(
        "--editor", action="store_true",
        help="open the Godot editor on the branch instead of playing",
    )
    parser.add_argument("--scene", help="a res:// scene to play instead of the main scene")
    parser.add_argument(
        "--real-saves", action="store_true",
        help="use your real profile instead of the separate van-gunner-try one",
    )
    args = parser.parse_args()

    if not args.branch:
        list_branches()
        return 0

    if args.branch == "main":
        if args.commit:
            print("main is already main: a shared-mode session commits its own work.")
            return 0
        tree = ROOT
        label = f"main (this checkout, your real profile)"
        landable = False
    else:
        branch, ref = resolve(args.branch)
        if args.commit:
            return land(branch, ref, args.smoke)
        ensure_tree(ref)
        write_override(TRY_DIR, args.real_saves)
        tree = TRY_DIR
        label = f"{branch} @ {git('rev-parse', '--short', ref)}  {git('log', '-1', '--format=%s', ref)[:80]}"
        landable = True

    exe = godot_exe()
    if tree != ROOT and not args.editor:
        import_scan(tree, exe)

    print(f"Trying {label}")
    print(f"Tree:  {tree}")
    if tree != ROOT and not args.real_saves:
        print("Saves and the schematic go to the separate van-gunner-try profile.")

    game = Game(exe, tree, args.scene, args.editor)

    if not sys.stdin.isatty():
        game.wait()
        return 0

    print(
        "Enter = stop."
        + ("  commit + Enter = land it on main as one commit (nothing is pushed)." if landable else "")
    )
    while True:
        try:
            ans = input("> ")
        except EOFError:
            # Nothing to read from (stdin at NUL reports isatty() on Windows): let the game run to its end.
            game.wait()
            return 0
        except KeyboardInterrupt:
            ans = ""
        ans = ans.strip().lower()
        if ans == "commit" and landable:
            game.stop()
            return land(branch, ref, args.smoke)
        elif ans == "":
            game.stop()
            print("Stopped.")
            return 0
        else:
            print("Type commit or press Enter." if landable else "Press Enter to stop.")


if __name__ == "__main__":
    sys.exit(main())
