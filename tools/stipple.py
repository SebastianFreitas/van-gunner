#!/usr/bin/env python3
"""Stipple meter: `py -3 tools/stipple.py <png or folder>... [--mark DIR] [--box X0,Y0,X1,Y1]`.

A stipple pixel is an isolated dark pixel: its luminance is at most DARK_RATIO
(0.4) of the median of its 3x3 neighbourhood, and that median is at least
MIN_SURROUND (30 of 255), so lit skin counts and the night does not. Prints
`STIPPLE <n> <file>` per picture and `STIPPLE TOTAL`.
Two softer outlier rules run beside it, on the same median (at least
MIN_SURROUND) and at least MIN_STEP (6 of 255) away from it: a light pixel is
at least LIGHT_RATIO (1.25) of the median, a dim pixel at most DIM_RATIO (0.8)
of it and not already dark (dark wins, so the two never overlap). Prints
`OUTLIER light <n> dim <n> <file>` per picture and `OUTLIER TOTAL`.
`--mark DIR` also saves each picture there with the counted pixels painted:
dark magenta, light cyan, dim yellow. `--box X0,Y0,X1,Y1` (pixels, X1 and Y1
exclusive) counts and marks only inside that box; the default is the whole
image. The count is only comparable between two shots of the same view. It
measures; it never fails.
"""
from __future__ import annotations

import argparse
import pathlib
import sys

from PIL import Image, ImageFilter

MIN_SURROUND = 30  # the 3x3 median must be at least this bright (0-255): lit skin, not the night
DARK_RATIO = 0.4  # a stipple pixel is at most this share of its 3x3 median
LIGHT_RATIO = 1.25  # a light outlier is at least this multiple of its 3x3 median
DIM_RATIO = 0.8  # a dim outlier is at most this share of its 3x3 median
MIN_STEP = 6  # a light or dim outlier is at least this far from the median (0-255)

DARK_COLOR = (255, 0, 255)
LIGHT_COLOR = (0, 255, 255)
DIM_COLOR = (255, 255, 0)


def count(
	path: pathlib.Path, mark: pathlib.Path | None, box: tuple[int, int, int, int] | None
) -> tuple[int, int, int]:
	"""(dark, light, dim) pixel counts in `path`; saves the marked copy into `mark` when given.

	Raises ValueError when `box` has no area after clipping to the image."""
	img = Image.open(path)
	lum = img.convert("L")
	med = lum.filter(ImageFilter.MedianFilter(3))
	w = lum.width
	x0, y0, x1, y1 = 0, 0, w, lum.height
	if box is not None:
		x0, y0 = max(box[0], 0), max(box[1], 0)
		x1, y1 = min(box[2], w), min(box[3], lum.height)
		if x0 >= x1 or y0 >= y1:
			raise ValueError("empty box")
	a = lum.tobytes()
	m = med.tobytes()
	dark: list[int] = []
	light: list[int] = []
	dim: list[int] = []
	for y in range(y0, y1):
		for i in range(y * w + x0, y * w + x1):
			if m[i] < MIN_SURROUND:
				continue
			if a[i] <= DARK_RATIO * m[i]:
				dark.append(i)
			elif a[i] >= LIGHT_RATIO * m[i] and a[i] - m[i] >= MIN_STEP:
				light.append(i)
			elif a[i] <= DIM_RATIO * m[i] and m[i] - a[i] >= MIN_STEP:
				dim.append(i)
	if mark is not None:
		mark.mkdir(parents=True, exist_ok=True)
		out = img.convert("RGB")
		for hits, color in ((dark, DARK_COLOR), (light, LIGHT_COLOR), (dim, DIM_COLOR)):
			for i in hits:
				out.putpixel((i % w, i // w), color)
		out.save(mark / (path.stem + ".png"))
	return len(dark), len(light), len(dim)


def main() -> int:
	parser = argparse.ArgumentParser(description="Count isolated dark, light and dim pixels in PNG shots.")
	parser.add_argument("paths", nargs="+", type=pathlib.Path, help="PNG files or folders")
	parser.add_argument("--mark", type=pathlib.Path, default=None, help="save marked copies here")
	parser.add_argument("--box", default=None, help="count only inside X0,Y0,X1,Y1 (X1, Y1 exclusive)")
	args = parser.parse_args()
	box: tuple[int, int, int, int] | None = None
	if args.box is not None:
		try:
			parts = [int(s) for s in args.box.split(",")]
			if len(parts) != 4:
				raise ValueError("need four ints")
			box = (parts[0], parts[1], parts[2], parts[3])
		except ValueError:
			print(f"stipple: bad --box {args.box}", file=sys.stderr)
			return 2
	files: list[pathlib.Path] = []
	for p in args.paths:
		if not p.exists():
			print(f"stipple: missing {p}", file=sys.stderr)
			return 2
		files.extend(sorted(p.glob("*.png")) if p.is_dir() else [p])
	if not files:
		print("stipple: no png files", file=sys.stderr)
		return 2
	total = 0
	light_total = 0
	dim_total = 0
	for f in files:
		try:
			n, light, dim = count(f, args.mark, box)
		except ValueError:
			print(f"stipple: bad --box {args.box}", file=sys.stderr)
			return 2
		total += n
		light_total += light
		dim_total += dim
		print(f"STIPPLE {n} {f.name}")
		print(f"OUTLIER light {light} dim {dim} {f.name}")
	print(f"STIPPLE TOTAL {total} ({len(files)} files)")
	print(f"OUTLIER TOTAL light {light_total} dim {dim_total} ({len(files)} files)")
	return 0


if __name__ == "__main__":
	sys.exit(main())
