#!/usr/bin/env python3
"""Gap-light meter: `py -3 tools/gap_check.py <shots dir> [--strict]`.

Counts the magenta pixels in the gap-light `g*.png` views that
`tools/smoke.py --shots DIR` saves. A magenta pixel is a see-through seam: the gap
light paints whatever shows through a gap magenta. The `gap-control-door-open` view
must be mostly magenta, or the gap light did not render. With `--strict` any other
view that shows magenta fails.
"""
from __future__ import annotations

import argparse
import pathlib
import sys

from PIL import Image, ImageChops

CONTROL_SUFFIX = "-gap-control-door-open"


def magenta_count(path: pathlib.Path) -> tuple[int, int]:
    """(magenta pixels, total pixels): R >= 180, B >= 180 and G <= 90."""
    with Image.open(path) as img:
        r, g, b = img.convert("RGB").split()
    mask = ImageChops.multiply(
        ImageChops.multiply(r.point(lambda v: 255 if v >= 180 else 0),
                            b.point(lambda v: 255 if v >= 180 else 0)),
        g.point(lambda v: 255 if v <= 90 else 0),
    )
    return mask.histogram()[255], mask.width * mask.height


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("dir", type=pathlib.Path, help="folder of --shots PNGs")
    parser.add_argument("--strict", action="store_true",
                        help="fail when a non-control view shows any magenta")
    args = parser.parse_args(argv)

    folder: pathlib.Path = args.dir
    files = sorted(folder.glob("g*.png")) if folder.is_dir() else []
    if not files:
        print(f"gap_check: FAIL no g*.png in {folder}")
        return 1

    rows: list[tuple[str, int, float]] = []
    for path in files:
        count, total = magenta_count(path)
        share = count / total * 100 if total else 0.0
        rows.append((path.stem, count, share))
        print(f"{path.stem}  {count} px  {share:.3f} %")

    control = [row for row in rows if row[0].endswith(CONTROL_SUFFIX)]
    if not control:
        print("gap_check: FAIL no gap-control-door-open view")
        return 1
    if control[0][2] < 1.0:
        print("gap_check: FAIL control view under 1 % magenta (the gap light did not render)")
        return 1
    if args.strict:
        bad = [stem for stem, count, _ in rows if not stem.endswith(CONTROL_SUFFIX) and count > 0]
        if bad:
            print(f"gap_check: FAIL {len(bad)} view(s) show magenta: {', '.join(bad)}")
            return 1
    print("gap_check: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
