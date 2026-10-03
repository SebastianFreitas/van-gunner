#!/usr/bin/env python3
"""Headless probe for van-gunner: `py -3 tools/probe.py [res://path.tscn] [--cmd "<console line>"]...
[--eval "<expr>"] [--frames N] [--shot out.png [--every <s> --max <n> | --views a,b]] [--timeout S]`.

Loads one scene headless and evaluates an expression against its root, or, with no
scene, boots the run (`SceneRouter.go_to_van()`, the van at IDLE) with the save
sandbox on. `--cmd` lines run through the debug console (`DebugCommands.run`) in
order before `--eval` and `--shot`. `--shot` renders in a real window on a hidden
Win32 desktop (never visible, never takes focus); with `--every`/`--max` it writes
`<stem>-01.png`...; with `--views` (--shot is then a directory) it writes one
`<view>.png` per `arms cam` view. Fails on any output line with SCRIPT ERROR / Parse Error / ERROR:,
a non-zero exit, a timeout, a missing `PROBE: done` line or a missing PNG.
"""
import argparse
import pathlib
import re
import subprocess
import sys

import hidden_desktop
from godot_env import godot_exe, project_lock, seed_import_cache


if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = pathlib.Path(__file__).resolve().parent.parent
FAILURE = re.compile(r"SCRIPT ERROR|Parse Error|ERROR:")
ANSI = re.compile(r"\x1b\[[0-9;]*m")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("scene", nargs="?", help="res://path to a .tscn/.scn to load")
    parser.add_argument("--cmd", action="append", default=[], help="debug console line to run")
    parser.add_argument("--eval", help="expression to evaluate against the scene root")
    parser.add_argument("--frames", type=int, default=10, help="frames to advance before eval")
    parser.add_argument("--shot", help="PNG path to render to on a hidden desktop")
    parser.add_argument("--every", type=float, help="seconds between repeated shots")
    parser.add_argument("--max", type=int, help="number of repeated shots")
    parser.add_argument("--views", help="with --shot DIR: one PNG per `arms cam` view")
    parser.add_argument("--timeout", type=int, default=180, help="timeout in seconds")

    opts = parser.parse_args()
    opts.views = [v.strip() for v in opts.views.split(",") if v.strip()] if opts.views else []
    if opts.views:
        if not opts.shot:
            parser.error("--views needs --shot")
        if opts.every is not None or opts.max is not None:
            parser.error("--views can't be combined with --every/--max")

    if opts.scene is not None:
        if not opts.scene.startswith("res://") or not (
            opts.scene.endswith(".tscn") or opts.scene.endswith(".scn")
        ):
            parser.error("scene must start with res:// and end with .tscn or .scn")

    if (opts.every is not None) != (opts.max is not None):
        parser.error("--every and --max must be given together")
    if opts.every is not None or opts.max is not None:
        if not opts.shot:
            parser.error("--every/--max need --shot")
        if opts.every <= 0 or opts.max <= 0:
            parser.error("--every and --max must be > 0")

    return opts


def resolve_shot(opts: argparse.Namespace) -> pathlib.Path | None:
    if not opts.shot:
        return None
    shot = pathlib.Path(opts.shot).resolve()
    (shot if opts.views else shot.parent).mkdir(parents=True, exist_ok=True)
    targets = expected_pngs(shot, opts)
    for target in targets:
        if target.exists():
            target.unlink()
    return shot


def expected_pngs(shot: pathlib.Path, opts: argparse.Namespace) -> list[pathlib.Path]:
    if opts.views:
        return [shot / f"{v}.png" for v in opts.views]
    if opts.max is not None:
        stem = shot.stem
        return [shot.with_name(f"{stem}-{n:02d}{shot.suffix}") for n in range(1, opts.max + 1)]
    return [shot]


def build_args(opts: argparse.Namespace, shot: pathlib.Path | None) -> list[str]:
    user = ["--smoke-sandbox"]
    if opts.scene:
        user.append("--probe-scene=" + opts.scene)
    for line in opts.cmd:
        user.append("--probe-cmd=" + line)
    if opts.eval:
        user.append("--probe-eval=" + opts.eval)
    user.append("--probe-frames=" + str(opts.frames))
    if shot is not None:
        user.append("--probe-shot=" + shot.as_posix())
        if opts.views:
            user.append("--probe-views=" + ",".join(opts.views))
        if opts.every is not None:
            user.append("--probe-every=" + str(opts.every))
        if opts.max is not None:
            user.append("--probe-max=" + str(opts.max))
    user.append("--probe-timeout=" + str(max(opts.timeout - 20, 10)))
    return user


def run_godot(
    exe: str, opts: argparse.Namespace, user: list[str], shot: pathlib.Path | None
) -> tuple[int, str] | int:
    if shot is not None:
        if sys.platform != "win32":
            print("PROBE FAILED: --shot needs the Windows hidden desktop")
            return 1
        args = [
            exe, "--path", str(ROOT),
            "--resolution", "1440x720", "res://tools/probe/probe_runner.tscn", "--", *user,
        ]
    else:
        args = [
            exe, "--headless", "--path", str(ROOT),
            "res://tools/probe/probe_runner.tscn", "--", *user,
        ]

    print("== probe: godot " + ("(hidden desktop) " if shot is not None else "--headless ")
          + "--path . res://tools/probe/probe_runner.tscn -- " + " ".join(user))

    with project_lock(ROOT):
        if shot is not None and sys.platform == "win32":
            try:
                returncode, output = hidden_desktop.run_hidden(args, ROOT, opts.timeout)
            except subprocess.TimeoutExpired:
                print(f"   timed out after {opts.timeout}s")
                print("PROBE FAILED: timed out")
                return 1
            except OSError as err:
                print(f"PROBE FAILED: could not start Godot on a hidden desktop: {err}")
                return 1
        else:
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
                print("PROBE FAILED: timed out")
                return 1
            returncode, output = proc.returncode, proc.stdout + proc.stderr

    return returncode, output


def report(
    returncode: int, output: str, shot: pathlib.Path | None, opts: argparse.Namespace
) -> int:
    lines = [ANSI.sub("", line.rstrip()) for line in output.splitlines()]
    for line in lines:
        if line.startswith("PROBE") or line.startswith("  "):
            print(line)

    hits = [line for line in lines if FAILURE.search(line)]
    for hit in hits:
        print("   " + hit)
    warnings = [line for line in lines if "WARNING:" in line]
    print(f"   {len(warnings)} warning(s)")
    print(f"   exit {returncode}, {len(hits)} failure line(s)")

    if hits:
        print(f"PROBE FAILED: {len(hits)} failure line(s)")
        return 1
    if returncode != 0:
        print(f"PROBE FAILED: exit code {returncode}")
        return 1
    if not any(line == "PROBE: done" for line in lines):
        print("PROBE FAILED: missing 'PROBE: done' line")
        return 1
    if shot is not None:
        missing = [target for target in expected_pngs(shot, opts) if not target.exists()]
        if missing:
            print("PROBE FAILED: missing " + ", ".join(str(m) for m in missing))
            return 1

    print("PROBE CLEAN")
    return 0


def main() -> int:
    opts = parse_args()
    shot = resolve_shot(opts)

    seed_import_cache(ROOT)
    exe = godot_exe()
    user = build_args(opts, shot)

    result = run_godot(exe, opts, user, shot)
    if isinstance(result, int):
        return result
    returncode, output = result

    return report(returncode, output, shot, opts)


if __name__ == "__main__":
    sys.exit(main())
