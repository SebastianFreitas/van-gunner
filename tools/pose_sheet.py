#!/usr/bin/env python3
"""Render one PNG grid per pinned arms pose: the poses of `tools/hand_shots.py` from fixed
cameras (default front, side, top and the player's view), one Godot launch per pose.

Usage: `py -3 tools/pose_sheet.py --out DIR [--pose NAME]... [--views front,side,top,player]
[--dress bare|rags|none] [--keep]`.
"""
from __future__ import annotations

import argparse
import math
import pathlib
import shutil
import sys

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("POSE SHEET FAILED: Pillow is missing (pip install pillow)")
    sys.exit(1)

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import hand_shots  # noqa: E402

GAP = 4
TITLE_H = 28
BACKGROUND = (24, 24, 24)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True, help="folder to write the sheets into")
    parser.add_argument(
        "--pose", action="append", default=[],
        help="pose name from hand_shots.py (repeatable); default all",
    )
    parser.add_argument("--views", default="front,side,top,player", help="comma list of cameras")
    parser.add_argument("--dress", choices=["bare", "rags", "none"], help="arms dress value")
    parser.add_argument("--timeout", type=int, default=180, help="timeout in seconds")
    parser.add_argument("--keep", action="store_true", help="keep the raw per-pose view PNGs")
    opts = parser.parse_args()

    for pose in opts.pose:
        if pose not in hand_shots.POSES:
            parser.error(f"unknown pose {pose!r}; poses: " + ", ".join(hand_shots.POSES))
    if not opts.pose:
        opts.pose = list(hand_shots.POSES)
    views = [v.strip() for v in opts.views.split(",") if v.strip()]
    bad = [v for v in views if v not in hand_shots.VIEW_NAMES]
    if not views or bad:
        parser.error("views must be from: " + ", ".join(hand_shots.VIEW_NAMES))
    opts.views = views
    return opts


def make_sheet(
    pose: str, lines: list[str], shot_dir: pathlib.Path, views: list[str], dest: pathlib.Path
) -> None:
    cells = []
    for view in views:
        path = shot_dir / f"{view}.png"
        if not path.exists():
            raise SystemExit(f"POSE SHEET FAILED: missing {path}")
        img = Image.open(path).convert("RGB")
        cells.append(img.resize((img.width // 2, img.height // 2), Image.Resampling.LANCZOS))

    try:
        font = ImageFont.load_default(size=18)
    except TypeError:
        font = ImageFont.load_default()

    cols = min(2, len(views))
    rows = math.ceil(len(views) / 2)
    cw, ch = cells[0].size
    sheet = Image.new(
        "RGB",
        (cols * cw + (cols - 1) * GAP, TITLE_H + rows * ch + (rows - 1) * GAP),
        BACKGROUND,
    )
    draw = ImageDraw.Draw(sheet)
    title = f"{pose}: " + ("; ".join(lines) if lines else "no pose forced")
    draw.text((8, 4), title, fill=(230, 230, 230), font=font)
    for i, (view, cell) in enumerate(zip(views, cells)):
        x = (i % 2) * (cw + GAP)
        y = TITLE_H + (i // 2) * (ch + GAP)
        sheet.paste(cell, (x, y))
        box = draw.textbbox((x + 8, y + 6), view, font=font)
        draw.rectangle(box, fill=(0, 0, 0))
        draw.text((x + 8, y + 6), view, fill=(255, 220, 120), font=font)
    sheet.save(dest)


def main() -> int:
    opts = parse_args()
    out = pathlib.Path(opts.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    sheets = []
    for pose in opts.pose:
        lines = ([f"arms dress {opts.dress}"] if opts.dress else []) + hand_shots.POSES[pose]
        shot_dir = out / "_views" / pose
        code = hand_shots.run_shots(lines, shot_dir, ",".join(opts.views), opts.timeout)
        if code != 0:
            print(f"POSE SHEET FAILED: pose {pose}")
            return code
        dest = out / f"{pose}.png"
        make_sheet(pose, lines, shot_dir, opts.views, dest)
        sheets.append(dest)
    if not opts.keep:
        shutil.rmtree(out / "_views", ignore_errors=True)
    print(f"POSE SHEET: {len(sheets)} sheet(s) in {out}")
    for sheet in sheets:
        print(f"  {sheet}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
