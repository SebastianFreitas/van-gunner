"""Shared Godot plumbing for the tools in this folder.

Used by check.py, smoke.py and scene_dump.py so the three scripts don't each carry
their own copy: locating the Godot executable (env var, Windows user variable, PATH,
~/.local/bin/godot), seeding a linked worktree's .godot/ import cache from the main
checkout, holding a per-project lock so two tools never run Godot on the same project
folder at once, and stamping a "last clean run" timestamp for the Claude Code Stop
hook to read.
"""
from __future__ import annotations

import contextlib
import json
import os
import pathlib
import shutil
import subprocess
import sys
import time
from typing import Iterator

LOCK_WAIT_SECONDS = 900
SEED_SKIP = ("export_credentials.cfg", "tools.lock", "claude-verify.json")
NO_GODOT = (
    "No Godot found: set GODOT to the Godot 4.7 executable "
    "(Godot_v4.7-stable_win64_console.exe on Windows) or put `godot` on PATH "
    "(cloud sessions: the environment's setup script runs tools/cloud_setup.sh)."
)


def find_godot() -> str | None:
    raw = os.environ.get("GODOT")
    if not raw and sys.platform == "win32":
        import winreg

        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as key:
                raw = os.path.expandvars(winreg.QueryValueEx(key, "GODOT")[0])
        except OSError:
            pass  # shells started before the variable was set don't inherit it
    if not raw:
        raw = shutil.which("godot")
    if not raw:
        local_bin = pathlib.Path.home() / ".local" / "bin" / "godot"
        if local_bin.exists():
            raw = str(local_bin)
    if not raw:
        return None
    exe = pathlib.Path(raw)
    if "console" not in exe.stem:
        console = exe.with_name(exe.stem + "_console" + exe.suffix)
        if console.exists():
            exe = console
    if not exe.exists():
        return None
    return str(exe)


def godot_exe() -> str:
    return find_godot() or sys.exit(NO_GODOT)


def main_checkout(root: pathlib.Path) -> pathlib.Path | None:
    try:
        proc = subprocess.run(
            ["git", "-C", str(root), "rev-parse", "--path-format=absolute", "--git-common-dir"],
            capture_output=True,
            text=True,
            timeout=10,
        )
    except Exception:
        return None
    if proc.returncode != 0:
        return None
    return pathlib.Path(proc.stdout.strip()).parent.resolve()


def seed_import_cache(root: pathlib.Path) -> bool:
    """Copy the main checkout's .godot/ into a linked worktree that has none, so its
    first import scan only redoes what differs (Godot compares source hashes, not
    times); never copies export credentials, the lock or the verify stamp.
    """
    dst = root / ".godot"
    if dst.exists():
        return False
    main = main_checkout(root)
    if main is None or main == root.resolve():
        return False
    src = main / ".godot"
    if not src.is_dir():
        return False
    print(f"   seeding .godot/ from {main}")
    try:
        shutil.copytree(src, dst, ignore=shutil.ignore_patterns(*SEED_SKIP))
    except OSError as err:
        print(f"   could not seed .godot/: {err}")
        return False
    return True


@contextlib.contextmanager
def project_lock(root: pathlib.Path) -> Iterator[None]:
    """Hold an OS lock on <root>/.godot/tools.lock while Godot runs, because parallel
    Godot runs on one project folder collide on .godot/; the OS drops the lock if the
    holder dies, so there are no stale locks.
    """
    path = root / ".godot" / "tools.lock"
    path.parent.mkdir(parents=True, exist_ok=True)
    handle = open(path, "a+b")
    deadline = time.monotonic() + LOCK_WAIT_SECONDS
    printed_waiting = False
    while True:
        try:
            _lock(handle)
            break
        except OSError:
            if time.monotonic() > deadline:
                handle.close()
                sys.exit(
                    f"Another Godot run kept {path} locked for {LOCK_WAIT_SECONDS} s; giving up."
                )
            if not printed_waiting:
                print("   waiting for another Godot run on this project folder to finish")
                printed_waiting = True
            time.sleep(1)
    try:
        yield
    finally:
        try:
            _unlock(handle)
        except OSError:
            pass
        handle.close()


def _lock(handle) -> None:  # handle: BinaryIO; left untyped to skip a single-use import
    if os.name == "nt":
        import msvcrt

        handle.seek(0)
        msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
    else:
        import fcntl

        fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)


def _unlock(handle) -> None:  # handle: BinaryIO; left untyped to skip a single-use import
    if os.name == "nt":
        import msvcrt

        handle.seek(0)
        msvcrt.locking(handle.fileno(), msvcrt.LK_UNLCK, 1)
    else:
        import fcntl

        fcntl.flock(handle.fileno(), fcntl.LOCK_UN)


def stamp_clean(root: pathlib.Path, kind: str) -> None:
    """Record when a check, smoke or scene dump last passed in .godot/claude-verify.json,
    which the Claude Code Stop hook compares with source mtimes.
    """
    path = root / ".godot" / "claude-verify.json"
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        data = {}
    data[kind] = time.time()
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data), encoding="utf-8")
    except OSError:
        pass
