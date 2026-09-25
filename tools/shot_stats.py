#!/usr/bin/env python3
"""Darkness meter for the art pass: `py -3 tools/shot_stats.py <shots_dir>`.

Reads the PNG screenshots that `tools/smoke.py --shots DIR` writes and prints
brightness stats per shot (mean and 95th-percentile linear luminance, share of
clipped pixels, mean saturation), so the dark-look budget can be checked with
numbers instead of eyeballing screenshots.
"""
from __future__ import annotations

import argparse
import pathlib
import sys

from PIL import Image

CLIP_LEVEL = 250


def srgb_to_linear(c: float) -> float:
	"""Standard sRGB EOTF; c and the result are both in 0..1."""
	if c <= 0.04045:
		return c / 12.92
	return ((c + 0.055) / 1.055) ** 2.4


def shot_kind(name: str) -> str:
	"""`"clean"` for HUD-free shots (stem ends with `-outside` or `-back`), else `"hud"`."""
	if name.endswith("-outside") or name.endswith("-back"):
		return "clean"
	return "hud"


def shot_stats(path: pathlib.Path) -> dict[str, float]:
	"""Mean and p95 linear luminance, clipped share and mean saturation for one PNG."""
	lut = [srgb_to_linear(i / 255.0) for i in range(256)]
	img = Image.open(path).convert("RGB")
	pixels = img.getdata()

	total = 0
	sum_y = 0.0
	sum_sat = 0.0
	clipped = 0
	bins = [0] * 4096

	for r, g, b in pixels:
		total += 1
		y = 0.2126 * lut[r] + 0.7152 * lut[g] + 0.0722 * lut[b]
		sum_y += y
		bins[int(y * 4095 + 0.5)] += 1

		mx = max(r, g, b)
		mn = min(r, g, b)
		sat = 0.0 if mx == 0 else (mx - mn) / mx
		sum_sat += sat

		if mx >= CLIP_LEVEL:
			clipped += 1

	threshold = 0.95 * total
	cumulative = 0
	p95_bin = 4095
	for bin_index, count in enumerate(bins):
		cumulative += count
		if cumulative >= threshold:
			p95_bin = bin_index
			break

	return {
		"mean": sum_y / total,
		"p95": p95_bin / 4095,
		"clipped": clipped / total,
		"sat": sum_sat / total,
	}


def main(argv: list[str] | None = None) -> int:
	parser = argparse.ArgumentParser(description="Print brightness stats for smoke screenshots.")
	parser.add_argument("shots_dir", type=pathlib.Path, help="folder of PNG screenshots")
	args = parser.parse_args(argv)

	shots_dir: pathlib.Path = args.shots_dir
	if not shots_dir.is_dir():
		print(f"error: {shots_dir} is not a directory", file=sys.stderr)
		return 2

	paths = sorted(shots_dir.glob("*.png"))
	if not paths:
		print(f"error: no PNG files in {shots_dir}", file=sys.stderr)
		return 2

	print(f"{'shot':<30} {'kind':<6} {'mean':>6} {'p95':>6} {'clip%':>7} {'sat':>6}")
	for path in paths:
		stats = shot_stats(path)
		kind = shot_kind(path.stem)
		print(
			f"{path.stem:<30} {kind:<6} {stats['mean']:>6.4f} {stats['p95']:>6.4f} "
			f"{stats['clipped'] * 100:>7.3f} {stats['sat']:>6.3f}"
		)

	return 0


if __name__ == "__main__":
	sys.exit(main())
