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

`--shots DIR` plays the same run in a real window placed off-screen instead of
headless, since headless Godot renders nothing, and saves PNGs to DIR at four
checkpoints (idle, combat, the elevator stop and the rear-park stop). After a
one-second settle, each checkpoint saves three views: the front as the player
sees it, the back through the rear doors, and an outside view from above the
cab looking back over the van; the UI is hidden for the back and outside
views. It writes an `override.cfg` next to project.godot for the run, so the
window renders but never takes the keyboard focus, and deletes it when the run
ends. Windows desktop only; behaviour of the headless run is unchanged.
"""
import argparse
import difflib
import os
import pathlib
import re
import subprocess
import sys

from godot_env import godot_exe, project_lock, seed_import_cache, stamp_clean

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = pathlib.Path(__file__).resolve().parent.parent
FAILURE = re.compile(r"SCRIPT ERROR|Parse Error|ERROR:")
ANSI = re.compile(r"\x1b\[[0-9;]*m")
TIMEOUT_SECONDS = 300

FINGERPRINT = ROOT / "tools" / "smoke" / "fingerprint.txt"
BASELINE = ROOT / "tools" / "smoke" / "fingerprint.baseline.txt"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--bless", action="store_true", help="rewrite fingerprint.baseline.txt after a clean run"
    )
    parser.add_argument(
        "--shots", metavar="DIR",
        help="play in an off-screen window and save screenshots to DIR (Windows desktop only)",
    )
    opts = parser.parse_args()

    if opts.bless and opts.shots:
        print("SMOKE FAILED: --bless and --shots don't mix; bless from a headless run")
        return 1

    if FINGERPRINT.exists():
        FINGERPRINT.unlink()

    shots: pathlib.Path | None = None
    if opts.shots:
        if sys.platform != "win32" and not os.environ.get("DISPLAY"):
            print(
                "SMOKE FAILED: --shots needs a display; this machine has none "
                "(cloud containers can't take screenshots)"
            )
            return 1
        shots = pathlib.Path(opts.shots).resolve()
        shots.mkdir(parents=True, exist_ok=True)
        for png in shots.glob("*.png"):
            png.unlink()
        override = ROOT / "override.cfg"
        if override.exists():
            print(
                "SMOKE FAILED: override.cfg already exists in this checkout; --shots writes its "
                "own. Move it away and run again."
            )
            return 1

    seed_import_cache(ROOT)
    exe = godot_exe()
    if shots is not None:
        args = [
            exe, "--path", str(ROOT), "--position", "-10000,-10000",
            "--resolution", "1440x720", "res://tools/smoke/smoke_test.tscn", "--",
            "--smoke-sandbox", "--smoke-shots=" + shots.as_posix(),
        ]
        print(
            "== smoke: godot --path . (off-screen window) res://tools/smoke/smoke_test.tscn -- "
            f"--smoke-sandbox --smoke-shots={shots.as_posix()}"
        )
    else:
        args = [
            exe, "--headless", "--path", str(ROOT),
            "res://tools/smoke/smoke_test.tscn", "--", "--smoke-sandbox",
        ]
        print("== smoke: godot --headless --path . res://tools/smoke/smoke_test.tscn -- --smoke-sandbox")
    with project_lock(ROOT):
        if shots is not None:
            override = ROOT / "override.cfg"
            override.write_text(
                "; Written by tools/smoke.py --shots for one run: the off-screen window renders\n"
                "; but never takes the keyboard focus. Deleted when the run ends.\n"
                "[display]\n"
                "\n"
                "window/size/no_focus=true\n",
                encoding="utf-8",
                newline="\n",
            )
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
        finally:
            if shots is not None:
                (ROOT / "override.cfg").unlink(missing_ok=True)

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

    if opts.bless:
        BASELINE.write_bytes(FINGERPRINT.read_bytes())
        print("BASELINE WRITTEN")
        stamp_clean(ROOT, "smoke")
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

    stamp_clean(ROOT, "smoke")
    if shots is not None:
        pngs = sorted(shots.glob("*.png"))
        print(f"   {len(pngs)} shot(s) in {shots}:")
        for png in pngs:
            print("     " + png.name)
    print("SMOKE CLEAN")
    return 0


if __name__ == "__main__":
    sys.exit(main())
