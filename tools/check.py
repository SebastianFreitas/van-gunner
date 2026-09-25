#!/usr/bin/env python3
"""Headless Godot check for van-gunner: `py -3 tools/check.py`.

Runs two Godot passes from the repo root and fails on any output line containing
SCRIPT ERROR, Parse Error or ERROR:. Godot's exit code alone is not reliable.

1. `--import`: the editor filesystem scan. Imports new assets and writes missing
   `.gd.uid` files. It does not compile scripts, which is why pass 2 exists.
2. `--script res://tools/check_scripts.gd`: loads every .gd, .tscn, .tres and
   .gdshader under res:// so parse errors and broken references surface.

GODOT holds the path to the Godot 4.7 executable; when it is unset, `godot` on PATH
(then ~/.local/bin/godot) is used, which is where tools/cloud_setup.sh installs it in
a cloud session. When the `_console` build sits next to the configured one it is used
instead, because the plain Windows build does not write its output to a pipe.
"""
import os
import pathlib
import re
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
FAILURE = re.compile(r"SCRIPT ERROR|Parse Error|ERROR:")
ANSI = re.compile(r"\x1b\[[0-9;]*m")
TIMEOUT_SECONDS = 600


def godot_exe() -> str:
    raw = os.environ.get("GODOT") or shutil.which("godot")
    if not raw:
        local_bin = pathlib.Path.home() / ".local" / "bin" / "godot"
        if local_bin.exists():
            raw = str(local_bin)
    if not raw:
        sys.exit(
            "No Godot found: set GODOT to the Godot 4.7 executable "
            "(Godot_v4.7-stable_win64_console.exe on Windows) or put `godot` on PATH "
            "(cloud sessions: the environment's setup script runs tools/cloud_setup.sh)."
        )
    exe = pathlib.Path(raw)
    if "console" not in exe.stem:
        console = exe.with_name(exe.stem + "_console" + exe.suffix)
        if console.exists():
            exe = console
    if not exe.exists():
        sys.exit(f"GODOT points at a missing file: {exe}")
    return str(exe)


def run_pass(exe: str, args: list[str], label: str) -> tuple[list[str], int]:
    print(f"== {label}: godot --headless --path . {' '.join(args)}")
    try:
        proc = subprocess.run(
            [exe, "--headless", "--path", str(ROOT), *args],
            cwd=ROOT,
            capture_output=True,
            encoding="utf-8",
            errors="replace",
            timeout=TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired:
        print(f"   timed out after {TIMEOUT_SECONDS}s")
        return [f"ERROR: {label} timed out"], 1
    lines = [ANSI.sub("", line.rstrip()) for line in (proc.stdout + proc.stderr).splitlines()]
    hits = [line for line in lines if FAILURE.search(line)]
    for hit in hits:
        print("   " + hit)
    print(f"   exit {proc.returncode}, {len(hits)} failure line(s)")
    return hits, proc.returncode


def main() -> int:
    exe = godot_exe()
    import_hits, _ = run_pass(exe, ["--import"], "import scan")
    load_hits, load_code = run_pass(
        exe, ["--script", "res://tools/check_scripts.gd"], "load check"
    )
    failures = len(import_hits) + len(load_hits)
    if failures or load_code != 0:
        print(f"CHECK FAILED: {failures} failure line(s), load check exit {load_code}")
        return 1
    print("CHECK CLEAN")
    return 0


if __name__ == "__main__":
    sys.exit(main())
