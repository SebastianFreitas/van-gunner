#!/usr/bin/env python3
"""Stipple meter: `py -3 tools/stipple.py <png or folder>... [--mark DIR]`.

A stipple pixel is an isolated dark pixel: its luminance is at most DARK_RATIO
(0.4) of the median of its 3x3 neighbourhood, and that median is at least
MIN_SURROUND (30 of 255), so lit skin counts and the night does not. Prints
`STIPPLE <n> <file>` per picture and `STIPPLE TOTAL`. `--mark DIR` also saves
each picture there with the counted pixels painted magenta. The count is only
comparable between two shots of the same view. It measures; it never fails.
"""
from __future__ import annotations

import argparse
import pathlib
import sys

from PIL import Image, ImageFilter

MIN_SURROUND = 30  # the 3x3 median must be at least this bright (0-255): lit skin, not the night
DARK_RATIO = 0.4  # a stipple pixel is at most this share of its 3x3 median


def count(path: pathlib.Path, mark: pathlib.Path | None) -> int:
	"""Number of stipple pixels in `path`; saves the marked copy into `mark` when given."""
	img = Image.open(path)
	lum = img.convert("L")
	med = lum.filter(ImageFilter.MedianFilter(3))
	a = lum.tobytes()
	m = med.tobytes()
	hits = [i for i in range(len(a)) if m[i] >= MIN_SURROUND and a[i] <= DARK_RATIO * m[i]]
	if mark is not None:
		mark.mkdir(parents=True, exist_ok=True)
		out = img.convert("RGB")
		w = out.width
		for i in hits:
			out.putpixel((i % w, i // w), (255, 0, 255))
		out.save(mark / (path.stem + ".png"))
	return len(hits)


def main() -> int:
	parser = argparse.ArgumentParser(description="Count isolated dark pixels in PNG shots.")
	parser.add_argument("paths", nargs="+", type=pathlib.Path, help="PNG files or folders")
	parser.add_argument("--mark", type=pathlib.Path, default=None, help="save marked copies here")
	args = parser.parse_args()
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
	for f in files:
		n = count(f, args.mark)
		total += n
		print(f"STIPPLE {n} {f.name}")
	print(f"STIPPLE TOTAL {total} ({len(files)} files)")
	return 0


if __name__ == "__main__":
	sys.exit(main())
