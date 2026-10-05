#!/usr/bin/env python3
"""Performance benchmark for van-gunner: `py -3 tools/perf.py [--seconds 30] [--save NAME]
[--compare NAME [--all]] [--vsync] [--timeout 320]`.

Runs the real game with the real renderer (a window on the hidden Win32 desktop, or under
`xvfb-run` on Linux, never `--headless`) and plays a fixed scenario: open the van, idle, cruise,
rush (speed mode) and fight. `tools/perf/perf_runner.gd` prints one `PERF <key>=<value>` line per
number; this script prints them, can save them to `.godot/perf/NAME.json` and compare a later run
against a saved one. Fails on any output line with SCRIPT ERROR / Parse Error / ERROR:, a non-zero
exit, a timeout or a missing `PERF: done` line. It takes the project lock but writes no verify
stamp: a benchmark is a measurement, never a stand-in for check or smoke.
"""
import argparse
import json
import pathlib
import re
import shutil
import subprocess
import sys

import hidden_desktop
from godot_env import godot_exe, project_lock, seed_import_cache


if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = pathlib.Path(__file__).resolve().parent.parent
FAILURE = re.compile(r"SCRIPT ERROR|Parse Error|ERROR:")
ANSI = re.compile(r"\x1b\[[0-9;]*m")
PAIR = re.compile(r"^PERF ([^\s=]+)=(\S+)$")
SCENE = "res://tools/perf/perf_test.tscn"
KEY_SUFFIXES = (".fps_avg", ".fps_low1", ".ms_p99", ".ms_max", ".hitches", ".draws")
KEY_EXACT = ("open.van_ready_ms", "open.arms_ms")
KEY_PARTS = (
    ".span.tile_spawn.", ".span.road_floor.", ".span.facade_side.",
    ".span.tile_step.", ".span.road_wreck.",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seconds", type=float, default=30.0, help="length of the cruise section")
    parser.add_argument("--save", metavar="NAME", help="write the numbers to .godot/perf/NAME.json")
    parser.add_argument("--compare", metavar="NAME", help="compare with a saved run")
    parser.add_argument("--all", action="store_true", help="compare every key, not the short list")
    parser.add_argument("--vsync", action="store_true", help="leave vsync on")
    parser.add_argument("--timeout", type=int, default=320, help="timeout in seconds")
    return parser.parse_args()


def perf_file(name: str) -> pathlib.Path:
    return ROOT / ".godot" / "perf" / f"{name}.json"


def run_godot(opts: argparse.Namespace) -> tuple[int, str] | int:
    user = ["--smoke-sandbox", f"--perf-seconds={opts.seconds}"]
    if opts.vsync:
        user.append("--perf-vsync")
    args = [godot_exe(), "--path", str(ROOT), "--resolution", "1440x720", SCENE, "--", *user]
    if sys.platform != "win32":
        # Linux (cloud sessions): a virtual X screen instead of the hidden desktop.
        if shutil.which("xvfb-run") is None:
            print("PERF FAILED: needs the Windows hidden desktop or xvfb-run on Linux")
            return 1
        args = [
            "xvfb-run", "-a", "-s", "-screen 0 1920x1080x24", *args[:3],
            "--rendering-driver", "opengl3", "--audio-driver", "Dummy", *args[3:],
        ]

    print("== perf: godot (hidden desktop) --path . " + SCENE + " -- " + " ".join(user))

    with project_lock(ROOT):
        if sys.platform == "win32":
            try:
                return hidden_desktop.run_hidden(args, ROOT, opts.timeout)
            except subprocess.TimeoutExpired:
                print(f"   timed out after {opts.timeout}s")
                print("PERF FAILED: timed out")
                return 1
            except OSError as err:
                print(f"PERF FAILED: could not start Godot on a hidden desktop: {err}")
                return 1
        try:
            proc = subprocess.run(
                args,
                cwd=ROOT,
                capture_output=True,
                encoding="utf-8",
                errors="replace",
                timeout=opts.timeout,
                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
            )
        except subprocess.TimeoutExpired:
            print(f"   timed out after {opts.timeout}s")
            print("PERF FAILED: timed out")
            return 1
        return proc.returncode, proc.stdout + proc.stderr


def report(returncode: int, output: str) -> tuple[int, dict[str, float | str]]:
    """Print the PERF lines; return (exit code so far, parsed key to value)."""
    lines = [ANSI.sub("", line.rstrip()) for line in output.splitlines()]
    for line in lines:
        if line.startswith("PERF"):
            print(line)

    hits = [line for line in lines if FAILURE.search(line)]
    for hit in hits:
        print("   " + hit)
    print(f"   exit {returncode}, {len(hits)} failure line(s)")

    values: dict[str, float | str] = {}
    for line in lines:
        match = PAIR.match(line)
        if match:
            key, text = match.groups()
            try:
                values[key] = float(text)
            except ValueError:
                values[key] = text

    if hits:
        print(f"PERF FAILED: {len(hits)} failure line(s)")
        return 1, values
    if returncode != 0:
        print(f"PERF FAILED: exit code {returncode}")
        return 1, values
    if not any(line == "PERF: done" for line in lines):
        print("PERF FAILED: missing 'PERF: done' line")
        return 1, values
    if not values.get("cruise.span.tile_spawn.count"):
        print("WARNING: the van did not drive during cruise")
    return 0, values


def wanted(key: str) -> bool:
    return (
        key in KEY_EXACT
        or key.startswith("open.span.")
        or key.endswith(KEY_SUFFIXES)
        or any(part in key for part in KEY_PARTS)
    )


def compare(name: str, values: dict[str, float | str], show_all: bool) -> int:
    path = perf_file(name)
    if not path.is_file():
        print(f"PERF FAILED: no saved run {path}")
        return 1
    before = json.loads(path.read_text(encoding="utf-8"))
    print(f"== compare with {name}")
    print(f"{'key':<46} {'before':>12} {'after':>12} {'change%':>9}")
    for key, after in values.items():
        old = before.get(key)
        if not isinstance(old, (int, float)) or not isinstance(after, (int, float)):
            continue
        if not show_all and not wanted(key):
            continue
        change = f"{(after - old) / old * 100:+.1f}" if old else "n/a"
        print(f"{key:<46} {old:>12.3f} {after:>12.3f} {change:>9}")
    return 0


def main() -> int:
    opts = parse_args()
    seed_import_cache(ROOT)

    result = run_godot(opts)
    if isinstance(result, int):
        return result
    code, values = report(*result)
    if code != 0:
        return code

    if opts.save:
        path = perf_file(opts.save)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(values, indent=2, sort_keys=True), encoding="utf-8", newline="\n")
        print(f"   saved {len(values)} values to {path}")
    if opts.compare and compare(opts.compare, values, opts.all) != 0:
        return 1

    print("PERF CLEAN")
    return 0


if __name__ == "__main__":
    sys.exit(main())
