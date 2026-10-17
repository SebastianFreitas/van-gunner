#!/usr/bin/env python3
"""Fixed close-up crops of the tools/hand_shots.py PNGs, before vs after.

`py -3 tools/hand_crops.py <before_dir> <after_dir> <out_dir>` cuts the same six
boxes out of the `rest_bare`, `rest_none` and `knock_none` sets of both folders
and writes `<out>/<name>_before.png` and `<name>_after.png` (the box upscaled
NEAREST by its scale). It prints `crop <name>: <n> px differ` per pair, then
`HAND CROPS done`; a missing PNG prints `crop <name>: missing <path>` and the
exit code is 1.
"""
from __future__ import annotations

import pathlib
import sys

from PIL import Image, ImageChops

# name: (set, view, x, y, w, h, scale), with w and h in source pixels. Recovered
# from the hands review crops on 2026-10-16 by template matching against the
# before shots (mean abs diff per channel 0.00 to 0.28, "curled" 0.02 at scale 1).
# They must never move: every phase of plan hands-geometry-pass is judged on
# these exact boxes.
CROPS = {
	"fingertips": ("rest_none", "left", 550, 250, 210, 170, 4),
	"knuckles": ("rest_none", "side", 830, 290, 180, 110, 4),
	"claws": ("rest_bare", "top", 360, 370, 150, 110, 4),
	"lhand": ("rest_none", "left", 540, 240, 350, 350, 2),
	"wrist_side": ("rest_bare", "side", 640, 360, 140, 160, 4),
	"curled": ("knock_none", "front", 400, 120, 640, 480, 1),
}


def main() -> int:
	if len(sys.argv) != 4:
		print("usage: hand_crops.py <before_dir> <after_dir> <out_dir>")
		return 2
	before = pathlib.Path(sys.argv[1])
	after = pathlib.Path(sys.argv[2])
	out = pathlib.Path(sys.argv[3])
	out.mkdir(parents=True, exist_ok=True)
	failed = False
	for name, (set_name, view, x, y, w, h, scale) in CROPS.items():
		boxes = []
		missing = ""
		for root in (before, after):
			path = root / set_name / (view + ".png")
			if not path.is_file():
				missing = str(path)
				break
			with Image.open(path) as img:
				boxes.append(img.convert("RGB").crop((x, y, x + w, y + h)))
		if missing:
			print("crop %s: missing %s" % (name, missing))
			failed = True
			continue
		for tag, box in zip(("before", "after"), boxes):
			big = box.resize((w * scale, h * scale), Image.NEAREST)
			big.save(out / ("%s_%s.png" % (name, tag)))
		diff = ImageChops.difference(boxes[0], boxes[1]).convert("L").point(
			lambda v: 255 if v else 0)
		count = diff.histogram()[255]
		print("crop %s: %d px differ" % (name, count))
	print("HAND CROPS done")
	return 1 if failed else 0


if __name__ == "__main__":
	sys.exit(main())
