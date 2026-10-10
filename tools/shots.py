#!/usr/bin/env python3
"""Named screenshot sets and a per-view same/changed comparison.

`py -3 tools/shots.py capture <name> [--van-seeds N]` runs a full windowed
smoke test (`tools/smoke.py --shots DIR`) on the hidden desktop and stores the
PNGs it writes under `.godot/shots/<name>/`. This is per checkout, gitignored
and kept between sessions, so a phase can capture a "before" set, make its
change, capture an "after" set and diff the two. Windows only; the capture
itself takes about 1-2 minutes since it plays a full van run in a real window.

`py -3 tools/shots.py compare <a> <b> [--raw]` compares two sets view by view,
where a view is a PNG stem shared between the two directories. `<a>` and `<b>`
each resolve to `.godot/shots/<x>/` if that exists, else to a plain path. The
diff metric (`view_diff`) is the mean of `ImageChops.difference` over all
pixels and the three RGB channels, on the 0..255 scale. A view is `same` when
its diff is at or under its tolerance (`tolerance`, from the `TOLERANCE`
table below), `changed` otherwise; a view present in only one set is
`only-a`/`only-b`, and a size mismatch is always `changed`. `--raw` skips the
tolerance check and just prints the diff per shared view, which is how the
tolerance table itself gets measured: capture the same unchanged tree twice
and look at the noise.

This lets a phase say "views X, Y must change, the rest stay same" and check
it with a command instead of eyeballing screenshots.
"""
from __future__ import annotations

import argparse
import pathlib
import re
import subprocess
import sys

from PIL import Image, ImageChops, ImageStat

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHOTS_ROOT = ROOT / ".godot" / "shots"
NAME_RE = re.compile(r"^[A-Za-z0-9_.-]+$")

# Tolerance per view is 2x the mean pixel diff measured between two `capture`
# runs of one unchanged tree on 2026-09-28 (workflow-port phase 7, D11;
# 05-combat-back, v04 and v16 re-measured 2026-10-01 once the IDLE van pin
# in smoke_shots.gd made the exterior views deterministic).
# 04-combat-front, 05-combat-back, 02-idle-back, 11-rear-park-stop-back re-measured 2026-10-05 as the
# largest diff over four captures, after smoke_seeds.gd pinned the smoke's own
# rolls and MachineMotion held still. The floor keeps a fully deterministic
# view from flagging float jitter; views measured at 0 rely on it. Unknown
# views (new views, `--van-seeds` views `v..-van-seed...`) fall back to
# DEFAULT_TOLERANCE. f01..f05 measured 2026-10-09 (van-floor phase 8); 04-combat-front and
# 08-elevator-stop-back, 10-rear-park-stop-front re-measured 2026-10-09 (their drift was noise between two captures).
# Re-measure with `compare <a> <b> --raw` on two fresh
# captures and double the result.
TOLERANCE_FLOOR = 0.05
DEFAULT_TOLERANCE = 1.0
TOLERANCE: dict[str, float] = {
	"01-idle-front": 0.008,
	"02-idle-back": 0.622,
	"03-idle-outside": 0.0,
	"04-combat-front": 3.694,
	"05-combat-back": 4.272,
	"06-combat-outside": 19.458,
	"07-elevator-stop-front": 0.106,
	"08-elevator-stop-back": 0.664,
	"09-elevator-stop-outside": 0.136,
	"10-rear-park-stop-front": 0.572,
	"11-rear-park-stop-back": 0.980,
	"12-rear-park-stop-outside": 0.014,
	"f01-floor-rear-low": 0.016,
	"f02-floor-stairs": 0.004,
	"f03-floor-mid-low": 0.036,
	"f04-floor-rear-high": 0.008,
	"f05-floor-plates-close": 0.012,
	"v01-idle-van-side-front": 0.0,
	"v02-idle-van-side-rear": 0.0,
	"v03-idle-van-low-front": 0.0,
	"v04-idle-front-wall": 0.104,
	"v05-idle-driver-wall": 0.004,
	"v06-idle-passenger-wall": 0.052,
	"v07-idle-ceiling-front": 0.002,
	"v08-idle-van-lit-side-front": 0.0,
	"v09-idle-van-lit-side-rear": 0.0,
	"v10-idle-van-lit-outside": 0.0,
	"v11-idle-van-lit-quarter-driver": 0.0,
	"v12-idle-van-lit-quarter-passenger": 0.0,
	"v13-idle-van-lit-front": 0.0,
	"v14-idle-van-lit-rear": 0.0,
	"v15-idle-van-lit-window": 0.0,
	"v16-idle-van-lit-roof": 0.0,
	# a19-arms-inspect measured 2026-10-10 (plan arms-inspect-anim phase 4): noise 0.043, tolerance 2x.
	"a19-arms-inspect": 0.086,
}


def tolerance(stem: str) -> float:
	"""Allowed diff for one view: the table entry (or the default), never below the floor."""
	return max(TOLERANCE.get(stem, DEFAULT_TOLERANCE), TOLERANCE_FLOOR)


def view_diff(a: pathlib.Path, b: pathlib.Path) -> float:
	"""Mean RGB difference between two PNGs, on the 0..255 scale."""
	img_a = Image.open(a).convert("RGB")
	img_b = Image.open(b).convert("RGB")
	diff = ImageChops.difference(img_a, img_b)
	return sum(ImageStat.Stat(diff).mean) / 3


def resolve_set(name: str) -> pathlib.Path | None:
	"""A named shot set under `.godot/shots/`, else a plain directory path, else None."""
	named = SHOTS_ROOT / name
	if named.is_dir():
		return named
	plain = pathlib.Path(name)
	if plain.is_dir():
		return plain
	return None


def capture(name: str, van_seeds: int) -> int:
	if not NAME_RE.match(name):
		print(f"SHOTS FAILED: bad name {name}")
		return 2

	target = SHOTS_ROOT / name
	cmd = [sys.executable, str(ROOT / "tools" / "smoke.py"), "--shots", str(target)]
	if van_seeds > 0:
		cmd += ["--van-seeds", str(van_seeds)]

	result = subprocess.run(cmd, cwd=ROOT)
	if result.returncode != 0:
		print(f"SHOTS FAILED: smoke --shots exited {result.returncode}")
		return 1

	pngs = sorted(target.glob("*.png"))
	if not pngs:
		print(f"SHOTS FAILED: no PNGs in {target}")
		return 1

	print(f"SHOTS CAPTURED {name}: {len(pngs)} view(s) in {target}")
	return 0


def compare(a_name: str, b_name: str, raw: bool) -> int:
	a_dir = resolve_set(a_name)
	if a_dir is None:
		print(f"SHOTS FAILED: no shot set {a_name}")
		return 2
	b_dir = resolve_set(b_name)
	if b_dir is None:
		print(f"SHOTS FAILED: no shot set {b_name}")
		return 2

	a_stems = {path.stem: path for path in a_dir.glob("*.png")}
	b_stems = {path.stem: path for path in b_dir.glob("*.png")}
	stems = sorted(set(a_stems) | set(b_stems))

	if raw:
		shared = 0
		for stem in stems:
			if stem not in a_stems or stem not in b_stems:
				continue
			shared += 1
			diff = view_diff(a_stems[stem], b_stems[stem])
			print(f"{stem:<36} diff={diff:.3f}")
		print(f"SHOTS RAW ({shared} views)")
		return 0

	changed = 0
	for stem in stems:
		if stem not in a_stems:
			print(f"{stem:<36} only-b")
			changed += 1
			continue
		if stem not in b_stems:
			print(f"{stem:<36} only-a")
			changed += 1
			continue

		img_a = Image.open(a_stems[stem])
		img_b = Image.open(b_stems[stem])
		if img_a.size != img_b.size:
			print(f"{stem:<36} changed  diff=size")
			changed += 1
			continue

		diff = view_diff(a_stems[stem], b_stems[stem])
		tol = tolerance(stem)
		verdict = "same" if diff <= tol else "changed"
		if verdict == "changed":
			changed += 1
		print(f"{stem:<36} {verdict:<8} diff={diff:.3f} tol={tol:.3f}")

	if changed == 0:
		print(f"SHOTS SAME ({len(stems)} views)")
		return 0
	print(f"SHOTS CHANGED: {changed} of {len(stems)} view(s)")
	return 1


def main(argv: list[str] | None = None) -> int:
	parser = argparse.ArgumentParser(description="Named screenshot sets and a same/changed comparison.")
	subparsers = parser.add_subparsers(dest="command")

	capture_parser = subparsers.add_parser("capture", help="capture a named screenshot set")
	capture_parser.add_argument("name", help="shot set name, stored under .godot/shots/<name>/")
	capture_parser.add_argument("--van-seeds", type=int, default=0, help="also shoot N van look seeds")

	compare_parser = subparsers.add_parser("compare", help="compare two screenshot sets view by view")
	compare_parser.add_argument("a", help="first shot set name or path")
	compare_parser.add_argument("b", help="second shot set name or path")
	compare_parser.add_argument("--raw", action="store_true", help="print diffs without a tolerance check")

	args = parser.parse_args(argv)

	if args.command == "capture":
		return capture(args.name, args.van_seeds)
	if args.command == "compare":
		return compare(args.a, args.b, args.raw)

	parser.print_usage()
	return 2


if __name__ == "__main__":
	sys.exit(main())
