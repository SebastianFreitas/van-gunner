#!/usr/bin/env python3
"""Headless smoke test for van-gunner: `py -3 tools/smoke.py [--bless]`.

Runs one Godot pass that plays a full van run headlessly (class pick, boons,
bench, combat, rest offer) with the save sandbox on, so it never touches a
real save on disk. Fails on any output line containing SCRIPT ERROR, Parse
Error or ERROR:, on a non-zero exit, on a timeout, or if the run does not log
`SMOKE: done`.

The run writes a deterministic fingerprint of class stats, loot pools, the
act deck and wave plans to tools/smoke/fingerprint.txt. Without `--bless`,
this is diffed against the committed tools/smoke/fingerprint.baseline.txt;
with `--bless`, the baseline is overwritten after a clean run.
"""
import difflib
import os
import pathlib
import re
import shutil
import subprocess
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = pathlib.Path(__file__).resolve().parent.parent
FAILURE = re.compile(r"SCRIPT ERROR|Parse Error|ERROR:")
ANSI = re.compile(r"\x1b\[[0-9;]*m")
TIMEOUT_SECONDS = 300

FINGERPRINT = ROOT / "tools" / "smoke" / "fingerprint.txt"
BASELINE = ROOT / "tools" / "smoke" / "fingerprint.baseline.txt"


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


def main() -> int:
    bless = "--bless" in sys.argv[1:]

    if FINGERPRINT.exists():
        FINGERPRINT.unlink()

    exe = godot_exe()
    args = [
        exe, "--headless", "--path", str(ROOT),
        "res://tools/smoke/smoke_test.tscn", "--", "--smoke-sandbox",
    ]
    print(f"== smoke: godot --headless --path . res://tools/smoke/smoke_test.tscn -- --smoke-sandbox")
    try:
        proc = subprocess.run(
            args,
            cwd=ROOT,
            capture_output=True,
            encoding="utf-8",
            errors="replace",
            timeout=TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired:
        print(f"   timed out after {TIMEOUT_SECONDS}s")
        print("SMOKE FAILED: timed out")
        return 1

    lines = [ANSI.sub("", line.rstrip()) for line in (proc.stdout + proc.stderr).splitlines()]
    hits = [line for line in lines if FAILURE.search(line)]
    for hit in hits:
        print("   " + hit)
    warnings = [line for line in lines if "WARNING:" in line]
    print(f"   {len(warnings)} warning(s)")
    smoke_lines = [line for line in lines if line.startswith("SMOKE:")]
    for line in smoke_lines:
        print("   " + line)
    print(f"   exit {proc.returncode}, {len(hits)} failure line(s)")

    if hits:
        print(f"SMOKE FAILED: {len(hits)} failure line(s)")
        return 1
    if proc.returncode != 0:
        print(f"SMOKE FAILED: exit code {proc.returncode}")
        return 1
    if not any(line == "SMOKE: done" for line in smoke_lines):
        print("SMOKE FAILED: missing 'SMOKE: done' line")
        return 1
    if not FINGERPRINT.exists():
        print("SMOKE FAILED: missing fingerprint.txt")
        return 1

    if bless:
        BASELINE.write_bytes(FINGERPRINT.read_bytes())
        print("BASELINE WRITTEN")
        print("SMOKE CLEAN")
        return 0

    if not BASELINE.exists():
        print("SMOKE FAILED: no baseline; run `py -3 tools/smoke.py --bless` first")
        return 1

    current = FINGERPRINT.read_text(encoding="utf-8").replace("\r\n", "\n")
    baseline = BASELINE.read_text(encoding="utf-8").replace("\r\n", "\n")
    if current != baseline:
        diff = difflib.unified_diff(
            baseline.splitlines(keepends=True),
            current.splitlines(keepends=True),
            fromfile="fingerprint.baseline.txt",
            tofile="fingerprint.txt",
        )
        sys.stdout.writelines(diff)
        print("SMOKE FAILED: fingerprint differs from baseline")
        return 1

    print("SMOKE CLEAN")
    return 0


if __name__ == "__main__":
    sys.exit(main())
