#!/usr/bin/env python3
"""Render the first-person goblin arms in chosen poses from fixed cameras, one Godot launch.

Usage: `py -3 tools/hand_shots.py --out DIR [--pose NAME | --pose "<console line>"]...
[--views front,side,left,top,elbow,gunleft,player] [--dress gear|rags|none] [--lamp]
[--timeout S]`.

Runs `tools/probe.py` with the pose's `arms` console lines and `--views`, so DIR gets one
`<view>.png` per camera. `--list` prints the named poses and exits.
"""
from __future__ import annotations

import argparse
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

# All but `player` are the `arms cam` views in scripts/debug/debug_arms_commands.gd (`VIEWS`);
# `player` is the player's own camera (handled in tools/probe/probe_runner.gd).
VIEW_NAMES = ["front", "side", "left", "top", "elbow", "gunleft", "player"]

POSES: dict[str, list[str]] = {
    "rest": [],  # the arms as they hang, no pose forced
    "weave": ["arms weave 1.2"],  # the idle weave sway, 1.2 s in
    "reload": ["arms reload 0.5"],  # the reload cycle at its midpoint
    "shot": ["arms shot 0.05"],  # the firing recoil just after the shot
    "knock": ["arms gesture knock contact"],  # knuckle on the door at the moment of contact
    "press": ["arms gesture press contact"],  # palm on the button at contact
    "push": ["arms gesture push contact"],  # both hands on the door at contact
    "pull": ["arms gesture pull contact"],  # hand gripping the handle at contact
    "slide_open": ["arms gesture slide_open contact"],  # hand on the sliding door opening it, at contact
    "slide_close": ["arms gesture slide_close contact"],  # hand on the sliding door closing it, at contact
    "walk": ["arms walk 0.25"],  # the walk bob a quarter through its cycle
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", help="folder to write the PNGs into")
    parser.add_argument(
        "--pose", action="append", default=[],
        help='pose name or a raw "arms ..." console line (repeatable); default rest',
    )
    parser.add_argument("--views", default=",".join(VIEW_NAMES), help="comma list of cameras")
    parser.add_argument("--dress", choices=["gear", "rags", "none"], help="arms dress value")
    parser.add_argument("--lamp", action="store_true", help="light the player view (arms lamp on)")
    parser.add_argument("--timeout", type=int, default=180, help="timeout in seconds")
    parser.add_argument("--list", action="store_true", help="print the poses and exit")
    opts = parser.parse_args()

    if opts.list:
        return opts
    if not opts.out:
        parser.error("--out is required")
    views = [v.strip() for v in opts.views.split(",") if v.strip()]
    bad = [v for v in views if v not in VIEW_NAMES]
    if not views or bad:
        parser.error("views must be from: " + ", ".join(VIEW_NAMES))
    opts.views = ",".join(views)
    for pose in opts.pose:
        if " " not in pose and pose not in POSES:
            parser.error(f"unknown pose {pose!r}; poses: " + ", ".join(POSES))
    return opts


def pose_lines(opts: argparse.Namespace) -> list[str]:
    lines = [f"arms dress {opts.dress}"] if opts.dress else []
    if opts.lamp:
        lines.insert(0, "arms lamp on")
    for pose in opts.pose or ["rest"]:
        lines.extend(POSES[pose] if " " not in pose else [pose])
    return lines


def run_shots(lines: list[str], out_dir: pathlib.Path, views: str, timeout: int) -> int:
    cmd = [sys.executable, str(ROOT / "tools" / "probe.py")]
    for line in lines:
        cmd += ["--cmd", line]
    cmd += ["--shot", str(out_dir), "--views", views, "--timeout", str(timeout)]
    return subprocess.run(cmd, cwd=ROOT).returncode


def main() -> int:
    opts = parse_args()
    if opts.list:
        for name, lines in POSES.items():
            print(f"{name}: " + ("; ".join(lines) if lines else "(no lines)"))
        return 0

    out_dir = pathlib.Path(opts.out).resolve()
    code = run_shots(pose_lines(opts), out_dir, opts.views, opts.timeout)
    if code != 0:
        return code
    pngs = [out_dir / f"{v}.png" for v in opts.views.split(",")]
    print(f"HAND SHOTS: {len(pngs)} PNG(s) in {out_dir}")
    for png in pngs:
        print(f"  {png}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
