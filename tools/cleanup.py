"""Remove session branches and worktrees whose work is already on main.

    py -3 tools/cleanup.py [--dry-run] [--idle-hours 24] [--keep BRANCH] [--quiet]

Removes local session branches (claude/*, worktree-*, plan-*, or any branch
checked out under .claude/worktrees) and their worktrees once their work is on
main and nobody has touched them for a while. Never pushes, never touches
origin, never deletes a branch whose work is not on main, and never removes a
worktree with uncommitted or untracked files.
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import time
from pathlib import Path


def _main_root() -> Path:
    here = Path(__file__).resolve().parent.parent
    r = subprocess.run(["git", "rev-parse", "--git-common-dir"], cwd=here, capture_output=True, text=True)
    if r.returncode != 0:
        return here
    return (here / r.stdout.strip()).resolve().parent

ROOT = _main_root()
WT_DIR = ROOT / ".claude" / "worktrees"


def run(*args: str, cwd: Path = ROOT) -> subprocess.CompletedProcess:
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True)


def git(*args: str, cwd: Path = ROOT, check: bool = False) -> str:
    r = run(*args, cwd=cwd)
    return r.stdout.strip() if r.returncode == 0 else ""


def rel(p: Path) -> str:
    try:
        return str(Path(p).resolve().relative_to(ROOT))
    except ValueError:
        return str(p)


def inside(p: Path, parent: Path) -> bool:
    try:
        Path(p).resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


def worktrees() -> dict[str, Path]:
    out: dict[str, Path] = {}
    path = None
    for line in git("worktree", "list", "--porcelain").splitlines():
        if line.startswith("worktree "):
            path = Path(line[len("worktree "):])
        elif line.startswith("branch refs/heads/") and path is not None:
            out[line[len("branch refs/heads/"):]] = path
    return out


def candidates(wts: dict[str, Path]) -> list[str]:
    current = git("branch", "--show-current")
    names = git("for-each-ref", "--format=%(refname:short)", "refs/heads").splitlines()
    result = []
    for b in names:
        b = b.strip()
        if not b or b == "main" or b == current:
            continue
        if b.startswith(("claude/", "worktree-", "plan-")) or (b in wts and inside(wts[b], WT_DIR)):
            result.append(b)
    return result


def landed(b: str) -> str | None:
    if run("show-ref", "--verify", "--quiet", f"refs/remotes/origin/{b}").returncode == 0:
        if run("merge-base", "--is-ancestor", f"origin/{b}", b).returncode != 0:
            return None
    if run("merge-base", "--is-ancestor", b, "main").returncode == 0:
        return "merged"
    mt = run("merge-tree", "--write-tree", "main", b)
    if mt.returncode == 0 and mt.stdout.splitlines() and mt.stdout.splitlines()[0].strip() == git("rev-parse", "main^{tree}"):
        return "on main"
    squash = git("log", "main", "-1", "--format=%ct", "--fixed-strings", "--grep", f"Squashed from {b}:")
    if squash:
        times = git("log", "--no-merges", "--format=%ct", f"main..{b}").split()
        if all(int(t) <= int(squash) for t in times):
            return "squashed"
    return None


def idle_hours(b: str, path: Path | None) -> float:
    stamps = []
    tip = git("log", "-1", "--format=%ct", b)
    if tip:
        stamps.append(float(tip))
    if path is not None:
        gd = git("rev-parse", "--git-dir", cwd=path)
        if gd:
            gdir = (path / gd).resolve()
            for name in ("index", "HEAD"):
                try:
                    stamps.append((gdir / name).stat().st_mtime)
                except OSError:
                    pass
    if not stamps:
        return 0.0
    return (time.time() - max(stamps)) / 3600


def dirty(path: Path) -> bool:
    if not Path(path).exists():
        return False
    return bool(git("status", "--porcelain", cwd=path))


def empty_leftovers() -> list[Path]:
    if not WT_DIR.is_dir():
        return []
    registered = {p.resolve() for p in worktrees().values()}
    out = []
    for d in sorted(WT_DIR.iterdir()):
        if not d.is_dir() or d.resolve() in registered:
            continue
        if not any(f.is_file() for f in d.rglob("*")):
            out.append(d)
    return out


def main() -> None:
    ap = argparse.ArgumentParser(description="Remove landed, idle session branches and worktrees.")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--idle-hours", type=float, default=24)
    ap.add_argument("--keep", action="append", default=[])
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()

    run("worktree", "prune")
    wts = worktrees()
    notes: list[str] = []
    removed = 0
    verb = "would remove" if args.dry_run else "removed"

    for b in candidates(wts):
        if b in args.keep:
            continue
        try:
            reason = landed(b)
            path = wts.get(b)
            if reason is None:
                notes.append(f"kept {b}: has work not on main")
                continue
            if path is not None and dirty(path):
                notes.append(f"kept {b}: uncommitted files in {rel(path)}")
                continue
            h = idle_hours(b, path)
            if h < args.idle_hours:
                notes.append(f"kept {b}: touched {h:.0f} h ago")
                continue
            if not args.dry_run:
                if path is not None:
                    r = run("worktree", "remove", str(path))
                    if r.returncode != 0:
                        err = (r.stderr.strip().splitlines() or [""])[0]
                        notes.append(f"kept {b}: could not remove {rel(path)}: {err}")
                        continue
                run("branch", "-D", b)
            print(f"cleanup: {verb} {b}" + (f" and {rel(path)}" if path is not None else "") + f" ({reason}, idle {h:.0f} h)")
            removed += 1
        except Exception as e:
            notes.append(f"kept {b}: error {e}")

    try:
        for d in empty_leftovers():
            if not args.dry_run:
                shutil.rmtree(d)
            print(f"cleanup: {verb} empty folder {rel(d)}")
            removed += 1
    except Exception as e:
        notes.append(f"empty folders skipped: error {e}")

    if not args.quiet:
        for n in notes:
            print("cleanup: " + n)
        if not removed and not notes:
            print("cleanup: nothing to remove")


if __name__ == "__main__":
    main()
