#!/usr/bin/env python3
"""Pin an animation at N times, shoot each through probe.py, and print step-to-step pixel diffs."""
from __future__ import annotations

import argparse
import pathlib
import subprocess
import sys
from pathlib import Path

try:
    from PIL import Image, ImageChops
except ImportError:
    print("anim_series: Pillow is missing (py -3 -m pip install pillow)")
    sys.exit(1)

ROOT = pathlib.Path(__file__).resolve().parent.parent
USAGE = (
    'usage: py -3 tools/anim_series.py --cmd "arms weave {t}" --times 0:3.6:8 --out DIR\n'
    '       [--region bottom40] [--threshold 12] [--dead 0.003] [--jump 0.06]\n'
    '       [--timeout 180] [--pre "<console line>"]...   (needs at least 2 times)'
)


def parse_times(spec: str) -> list[float]:
    """'start:end:count' (end exclusive) or a comma list like '0,0.5,1.2'."""
    if ":" in spec:
        start_s, end_s, count_s = spec.split(":")
        start, end, count = float(start_s), float(end_s), int(count_s)
        return [start + (end - start) * i / count for i in range(count)]
    return [float(part) for part in spec.split(",") if part.strip()]


def parse_region(spec: str, w: int, h: int) -> tuple[int, int, int, int]:
    """'bottom40' (full width, lowest 40%) or 'x0,y0,x1,y1' as fractions 0..1."""
    if spec.startswith("bottom"):
        pct = float(spec[len("bottom"):])
        return (0, int(round(h * (1.0 - pct / 100.0))), w, h)
    x0, y0, x1, y1 = (float(part) for part in spec.split(","))
    return (int(round(x0 * w)), int(round(y0 * h)), int(round(x1 * w)), int(round(y1 * h)))


def capture(cmd_template: str, t: float, out_png: Path, timeout: int, pre: list[str] | None = None) -> None:
    """Run probe.py with the pinned command; exit 1 with the output tail on failure."""
    argv = [sys.executable, str(ROOT / "tools" / "probe.py")]
    for line in pre or []:
        argv += ["--cmd", line]
    argv += ["--cmd", cmd_template.replace("{t}", "%.3f" % t)]
    argv += ["--shot", str(out_png), "--timeout", str(timeout)]
    proc = subprocess.run(argv, cwd=ROOT, capture_output=True, text=True)
    output = (proc.stdout or "") + (proc.stderr or "")
    if "PROBE CLEAN" not in output or not out_png.exists():
        print("\n".join(output.splitlines()[-20:]))
        sys.exit(1)


def changed_fraction(a_png: Path, b_png: Path, region, threshold: int) -> float:
    """Share of region pixels whose max channel difference exceeds the threshold."""
    with Image.open(a_png) as a_img, Image.open(b_png) as b_img:
        a = a_img.convert("RGB")
        b = b_img.convert("RGB")
    if a.size != b.size:
        print(f"anim_series: PNG sizes differ: {a_png.name} {a.size} vs {b_png.name} {b.size}")
        sys.exit(1)
    x0, y0, x1, y1 = parse_region(region, *a.size) if isinstance(region, str) else region
    diff = ImageChops.difference(a, b).crop((x0, y0, x1, y1))
    r, g, bl = diff.split()
    peak = ImageChops.lighter(ImageChops.lighter(r, g), bl)
    hist = peak.histogram()
    total = sum(hist)
    if total == 0:
        return 0.0
    return sum(hist[threshold + 1:]) / total


def main() -> int:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--cmd", default="")
    parser.add_argument("--times", default="")
    parser.add_argument("--out", default="")
    parser.add_argument("--region", default="bottom40")
    parser.add_argument("--threshold", type=int, default=12)
    parser.add_argument("--dead", type=float, default=0.003)
    parser.add_argument("--jump", type=float, default=0.06)
    parser.add_argument("--timeout", type=int, default=180)
    parser.add_argument("--pre", action="append", default=[])
    opts, _unknown = parser.parse_known_args()

    try:
        times = parse_times(opts.times) if opts.times else []
    except ValueError:
        times = []
    if len(times) < 2 or not opts.cmd or not opts.out:
        print(USAGE)
        return 2

    out_dir = pathlib.Path(opts.out).resolve()
    if out_dir == ROOT or ROOT in out_dir.parents:
        print(f"anim_series: --out must be outside the repo ({ROOT}): scratch only")
        return 1
    out_dir.mkdir(parents=True, exist_ok=True)
    old = sorted(out_dir.glob("s-*.png"))
    if old:
        print(f"removing {len(old)} old s-*.png from {out_dir}")
        for path in old:
            path.unlink()

    shots: list[Path] = []
    for k, t in enumerate(times):
        png = out_dir / f"s-{k:02d}.png"
        capture(opts.cmd, t, png, opts.timeout, opts.pre)
        shots.append(png)
        print(f"step {k}  t={t:.3f}  shot ok", flush=True)

    steps: list[tuple[int, float, float, float]] = []
    for k in range(1, len(times)):
        frac = changed_fraction(shots[k - 1], shots[k], opts.region, opts.threshold)
        steps.append((k, times[k - 1], times[k], frac))
    wrap = changed_fraction(shots[-1], shots[0], opts.region, opts.threshold)

    print("k  t_prev -> t  changed%")
    for k, t_prev, t, frac in steps:
        print(f"{k}  {t_prev:.3f} -> {t:.3f}  {frac * 100:.2f}%")
    print(f"wrap  {times[-1]:.3f} -> {times[0]:.3f}  {wrap * 100:.2f}%")

    fracs = [s[3] for s in steps]
    dead = [s[0] for s in steps if s[3] < opts.dead]
    jumps = [s[0] for s in steps if s[3] > opts.jump]
    print(
        f"min {min(fracs) * 100:.2f}%  max {max(fracs) * 100:.2f}%  "
        f"mean {sum(fracs) / len(fracs) * 100:.2f}%  "
        f"dead: {dead or 'none'}  jumps: {jumps or 'none'}"
    )

    csv_dead = ",".join(str(k) for k in dead)
    csv_jump = ",".join(str(k) for k in jumps)
    if dead and jumps:
        print("ANIM SERIES FLAT+JUMPY")
        return 1
    if dead:
        print(f"ANIM SERIES FLAT: {csv_dead}")
        return 1
    if jumps:
        print(f"ANIM SERIES JUMPY: {csv_jump}")
        return 1
    print("ANIM SERIES OK")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
