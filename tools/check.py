#!/usr/bin/env python3
"""Headless Godot check for van-gunner: `py -3 tools/check.py`.

Runs three Godot passes from the repo root and fails on any output line containing
SCRIPT ERROR, Parse Error or ERROR:. Godot's exit code alone is not reliable.

1. `--import`: the editor filesystem scan. Imports new assets and writes missing
   `.gd.uid` files. It does not compile scripts, which is why pass 2 exists.
2. `--script res://tools/check_scripts.gd`: loads every .gd, .tscn, .tres and
   .gdshader under res:// so parse errors and broken references surface.
3. The same load with the local debugger attached (-d), which is the only way Godot
   prints GDScript warnings; any warning fails the check because the tree is kept at 0.

Godot discovery (env var, then the Windows user variable, then PATH, then
~/.local/bin/godot) lives in godot_env.py, shared with smoke.py and scene_dump.py.
Runs take a per-project lock so two tools never run Godot on this folder at once.
"""
import pathlib
import re
import subprocess
import sys
import time

from godot_env import godot_exe, project_lock, seed_import_cache, stamp_clean

ROOT = pathlib.Path(__file__).resolve().parent.parent
FAILURE = re.compile(r"SCRIPT ERROR|Parse Error|ERROR:")
ANSI = re.compile(r"\x1b\[[0-9;]*m")
TIMEOUT_SECONDS = 600


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


def run_warning_pass(exe: str) -> list[str]:
    print("== warnings: godot --headless -d --path . --script res://tools/check_scripts.gd")
    try:
        # -d attaches the local debugger, the only way Godot prints GDScript warnings;
        # stdin at EOF ends any debugger break.
        proc = subprocess.run(
            [
                exe, "--headless", "-d", "--path", str(ROOT),
                "--script", "res://tools/check_scripts.gd",
            ],
            cwd=ROOT,
            stdin=subprocess.DEVNULL,
            capture_output=True,
            encoding="utf-8",
            errors="replace",
            timeout=TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired:
        print(f"   timed out after {TIMEOUT_SECONDS}s")
        return ["ERROR: warnings pass timed out"]
    lines = [ANSI.sub("", line.rstrip()) for line in (proc.stdout + proc.stderr).splitlines()]
    found: list[str] = []
    marker = "GDScript::reload ("
    for i, line in enumerate(lines[:-1]):
        if not line.lstrip().startswith("WARNING:"):
            continue
        next_line = lines[i + 1]
        if marker + "res://" not in next_line:
            continue
        start = next_line.index(marker) + len(marker)
        loc = next_line[start:next_line.index(")", start)]
        msg = line.strip().removeprefix("WARNING:").strip()
        found.append(f"{loc}: {msg}")
    for hit in found:
        print("   " + hit)
    print(f"   {len(found)} GDScript warning(s)")
    return found


def main() -> int:
    seed_import_cache(ROOT)
    exe = godot_exe()
    with project_lock(ROOT):
        started = time.time()
        import_hits, _ = run_pass(exe, ["--import"], "import scan")
        load_hits, load_code = run_pass(
            exe, ["--script", "res://tools/check_scripts.gd"], "load check"
        )
        warnings = run_warning_pass(exe)
    failures = len(import_hits) + len(load_hits)
    if failures or load_code != 0:
        print(f"CHECK FAILED: {failures} failure line(s), load check exit {load_code}")
        return 1
    if warnings:
        print(f"CHECK FAILED: {len(warnings)} GDScript warning(s); the tree is kept at 0")
        return 1
    stamp_clean(ROOT, "check", started)
    print("CHECK CLEAN")
    return 0


if __name__ == "__main__":
    sys.exit(main())
