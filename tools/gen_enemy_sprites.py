"""Draw the two base beast sprites (door and window raider) as flat pixel art.

Owner's design (2026-10-01): no more humanoids. Both raiders are cat-like
beasts in washed yellow, big lolling tongues, a red stripe centred on the
face that runs up the back in white and onto a full white tail. The door
raider is the big fat one with the huge head (easy to hit); the window
raider is the low crawler that fits through a side window.

Art rules (.claude/rules/art-style.md, pixel art): native size, one image
pixel = one art pixel at pixel_size 0.024 (2.4 cm); flat colours, no
anti-aliasing, alpha 0 or 255; hard shadows lit from the upper left (base,
one shadow, one highlight per material); a hard one-pixel outline.

Every shape is a predicate over integer pixels, so the drawing is exact and
deterministic. Usage:

    py -3 tools/gen_enemy_sprites.py              # writes scenes/enemies/*.png
    py -3 tools/gen_enemy_sprites.py --preview D  # also 6x previews in D
    py -3 tools/gen_enemy_sprites.py --out D      # draft somewhere else first
"""
from __future__ import annotations

import argparse
import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "scenes" / "enemies"

# Canvas sizes: the fat beast is 1.92 x 1.73 m, the crawler 1.92 x 1.15 m.
FAT_SIZE = (80, 72)
CRAWLER_SIZE = (80, 48)

OUTLINE = (30, 20, 18)
YEL_HI = (222, 204, 136)
YEL = (204, 186, 114)
YEL_SH = (150, 130, 74)
YEL_DEEP = (102, 86, 48)
WHITE_HI = (244, 242, 232)
WHITE = (224, 220, 206)
WHITE_SH = (166, 160, 142)
RED = (192, 42, 36)
RED_SH = (130, 26, 26)
TONGUE_HI = (236, 140, 142)
TONGUE = (214, 84, 96)
TONGUE_SH = (156, 46, 60)
MOUTH = (58, 18, 22)
NOSE = (74, 26, 28)
TEETH = (242, 238, 226)
EYE = (178, 224, 84)
PUPIL = (18, 14, 12)


class Canvas:
	"""A tiny raster of RGB tuples (None = transparent) with outlined parts."""

	def __init__(self, size: tuple[int, int]) -> None:
		self.w, self.h = size
		self.px: list[list[tuple[int, int, int] | None]] = [
			[None] * self.w for _ in range(self.h)]

	def pixels(self):
		for y in range(self.h):
			for x in range(self.w):
				yield x, y

	def mask(self, pred) -> set[tuple[int, int]]:
		return {(x, y) for x, y in self.pixels() if pred(x, y)}

	def set(self, x: int, y: int, c: tuple[int, int, int]) -> None:
		if 0 <= x < self.w and 0 <= y < self.h:
			self.px[y][x] = c

	def outline(self, m: set[tuple[int, int]]) -> None:
		"""One hard pixel around the mask, over whatever is there."""
		for x, y in m:
			for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
				if (x + dx, y + dy) not in m:
					self.set(x + dx, y + dy, OUTLINE)

	def part(self, m, base, shadow, hi, shade, sh_at=0.45, hi_at=-0.9,
			outline=True) -> set[tuple[int, int]]:
		"""Fill a mask with three tones split by hard edges, outlined."""
		if outline:
			self.outline(m)
		for x, y in m:
			s = shade(x, y)
			self.set(x, y, hi if s < hi_at else shadow if s > sh_at else base)
		return m

	def fill(self, m, c) -> None:
		for x, y in m:
			self.set(x, y, c)

	def save(self, path: Path) -> Image.Image:
		im = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
		for x, y in self.pixels():
			c = self.px[y][x]
			if c is not None:
				im.putpixel((x, y), (c[0], c[1], c[2], 255))
		im.save(path)
		return im


# --- shape predicates ---------------------------------------------------------

def ellipse(cx, cy, rx, ry):
	return lambda x, y: ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0


def capsule(x0, y0, x1, y1, r0, r1=None):
	"""Points within a radius (lerped r0..r1) of the segment."""
	r1 = r0 if r1 is None else r1
	dx, dy = x1 - x0, y1 - y0
	ll = dx * dx + dy * dy or 1.0

	def pred(x, y):
		t = max(0.0, min(1.0, ((x - x0) * dx + (y - y0) * dy) / ll))
		px, py = x0 + t * dx, y0 + t * dy
		r = r0 + (r1 - r0) * t
		return (x - px) ** 2 + (y - py) ** 2 <= r * r
	return pred


def polyline(points, r):
	segs = [capsule(*points[i], *points[i + 1], r) for i in range(len(points) - 1)]
	return lambda x, y: any(s(x, y) for s in segs)


def polygon(pts):
	def pred(x, y):
		px, py = x + 0.5, y + 0.5
		inside = False
		n = len(pts)
		for i in range(n):
			(ax, ay), (bx, by) = pts[i], pts[(i + 1) % n]
			if (ay > py) != (by > py):
				ix = ax + (py - ay) * (bx - ax) / (by - ay)
				if px < ix:
					inside = not inside
		return inside
	return pred


def both(a, b):
	return lambda x, y: a(x, y) and b(x, y)


def light(cx, cy, rx, ry, kx=0.75, ky=0.65):
	"""Signed position along the upper-left light: negative is lit."""
	return lambda x, y: (x - cx) / rx * kx + (y - cy) / ry * ky


def top_band(cx, cy, rx, ry, depth):
	"""The strip just under an ellipse's top edge: the spine seen from the front."""
	def pred(x, y):
		u = (x - cx) / rx
		if abs(u) >= 1.0:
			return False
		top = cy - ry * math.sqrt(1.0 - u * u)
		return top <= y < top + depth
	return pred


# --- the two beasts ------------------------------------------------------------

def draw_face(c: Canvas, head_m, hx, hy, hrx, hry, eye_dx, eye_ry, stripe_w,
		mouth_cy, mouth_rx, mouth_ry, tongue_cy, tongue_rx, tongue_ry, ear_pts):
	"""Ears, red face stripe, eyes, mouth, teeth and the big tongue."""
	for pts in ear_pts:
		ear = c.mask(polygon(pts))
		c.part(ear, YEL, YEL_SH, YEL_HI, light(hx, hy, hrx, hry))
		(ax, ay), (bx, by), (cx_, cy_) = pts
		inner = polygon([((ax * 2 + bx) / 3, (ay * 2 + by) / 3),
			((ax + bx * 4 + cx_) / 6, (ay + by * 4 + cy_) / 6),
			((cx_ * 2 + bx) / 3, (cy_ * 2 + by) / 3)])
		c.fill(c.mask(both(inner, polygon(pts))), YEL_DEEP)
	# Red stripe down the centre of the face, lit side left.
	half = stripe_w // 2
	nose_y = mouth_cy - mouth_ry - 1
	stripe = {(x, y) for x, y in head_m if abs(x - hx) <= half and y <= nose_y}
	c.fill(stripe, RED)
	c.fill({p for p in stripe if p[0] > hx}, RED_SH)
	c.fill(c.mask(ellipse(hx, nose_y, half + 0.5, 1.5)), NOSE)
	# Eyes: pale green with a black slit.
	for ex in (hx - eye_dx, hx + eye_dx):
		ey = hy - hry * 0.25
		eye = c.mask(ellipse(ex, ey, eye_dx * 0.45, eye_ry))
		c.outline(eye)
		c.fill(eye, EYE)
		for yy in range(int(ey - eye_ry), int(ey + eye_ry) + 1):
			c.set(int(ex), yy, PUPIL)
	# Mouth, teeth hanging from the upper lip, then the tongue over it all.
	mouth = c.mask(ellipse(hx, mouth_cy, mouth_rx, mouth_ry))
	c.outline(mouth)
	c.fill(mouth, MOUTH)
	for tx in (hx - mouth_rx * 0.7, hx - mouth_rx * 0.35, hx + mouth_rx * 0.35,
			hx + mouth_rx * 0.7):
		tooth = polygon([(tx - 1, mouth_cy - mouth_ry), (tx + 1.5, mouth_cy - mouth_ry),
			(tx + 0.25, mouth_cy - mouth_ry + 3.5)])
		c.fill(c.mask(both(tooth, lambda x, y: (x, y) in mouth)), TEETH)
	tongue = c.mask(ellipse(hx + 1, tongue_cy, tongue_rx, tongue_ry))
	c.part(tongue, TONGUE, TONGUE_SH, TONGUE_HI,
		light(hx + 1, tongue_cy, tongue_rx, tongue_ry, 1.0, 0.5), 0.5, -0.8)
	for yy in range(int(tongue_cy - tongue_ry * 0.5), int(tongue_cy + tongue_ry * 0.85)):
		c.set(hx + 1, yy, TONGUE_SH)


def draw_leg(c: Canvas, x0, y0, x1, y1, r, paw_rx, paw_ry, claw_dir=1):
	leg = c.mask(capsule(x0, y0, x1, y1, r))
	c.part(leg, YEL, YEL_SH, YEL_HI, light(x1, y1, r * 2, r * 2, 1.0, 0.2), 0.3, -1.1)
	paw = c.mask(ellipse(x1, y1, paw_rx, paw_ry))
	c.part(paw, YEL, YEL_SH, YEL_HI, light(x1, y1, paw_rx, paw_ry, 1.0, 0.4), 0.5, -1.2)
	for i in (-1, 0, 1):
		cx = int(x1 + i * paw_rx * 0.55)
		c.set(cx, int(y1 + paw_ry) - 1, OUTLINE)
		c.set(cx, int(y1 + paw_ry) - 2, OUTLINE)


def draw_tail(c: Canvas, points, r, lx, ly):
	tail = c.mask(polyline(points, r))
	c.part(tail, WHITE, WHITE_SH, WHITE_HI, light(lx, ly, 10, 10, 0.7, 0.7), 0.75, -0.5)


def draw_fat_beast() -> Canvas:
	c = Canvas(FAT_SIZE)
	bx, by, brx, bry = 46, 38, 30, 24
	hx, hy, hrx, hry = 37, 38, 23, 20
	# Back leg peeking out at the rear right, then the fat body.
	draw_leg(c, 67, 50, 67, 64, 5, 7, 3.5)
	body = c.mask(ellipse(bx, by, brx, bry))
	c.part(body, YEL, YEL_SH, YEL_HI, light(bx, by, brx, bry), 0.5, -0.85)
	# Chest under the chin falls into deep shadow.
	c.fill({(x, y) for x, y in body if y >= 56 and abs(x - hx) <= 19}, YEL_DEEP)
	# White spine along the top of the back, from behind the crown to the tail root.
	spine = c.mask(both(top_band(bx, by, brx, bry, 7),
		lambda x, y: 32 <= x <= 70 and (x, y) in body))
	c.fill(spine, WHITE_HI)
	c.fill({p for p in spine if p[0] > 58}, WHITE)
	draw_tail(c, [(64, 19), (70, 11), (74, 5), (69, 2), (62, 3)], 3.6, 70, 6)
	# Front legs, then the huge head over the chest.
	draw_leg(c, 18, 52, 18, 65, 5, 7, 3.5)
	draw_leg(c, 58, 52, 58, 65, 5, 7, 3.5)
	head = c.mask(ellipse(hx, hy, hrx, hry))
	c.part(head, YEL, YEL_SH, YEL_HI, light(hx, hy, hrx, hry), 0.5, -0.85)
	# The red stripe turns white where it leaves the crown for the back.
	c.fill({(x, y) for x, y in body if abs(x - hx) <= 3 and y < hy - hry + 1}, WHITE_HI)
	draw_face(c, head, hx, hy, hrx, hry, eye_dx=11, eye_ry=3, stripe_w=7,
		mouth_cy=52, mouth_rx=14, mouth_ry=4, tongue_cy=60, tongue_rx=7, tongue_ry=10,
		ear_pts=[[(16, 27), (21, 7), (31, 21)], [(43, 21), (53, 7), (58, 27)]])
	return c


def draw_crawler() -> Canvas:
	c = Canvas(CRAWLER_SIZE)
	hx, hy, hrx, hry = 24, 26, 15, 12
	# Low body, rising toward the rear, with the hips a little fuller.
	body = c.mask(capsule(30, 30, 68, 22, 10, 9))
	c.part(body, YEL, YEL_SH, YEL_HI, light(49, 26, 24, 10, 0.5, 0.8), 0.5, -0.9)
	spine = c.mask(both(
		lambda x, y: 30 <= x <= 72 and (x, y) in body,
		lambda x, y: (x, y - 1) not in body or (x, y - 2) not in body
			or (x, y - 3) not in body or (x, y - 4) not in body))
	c.fill(spine, WHITE_HI)
	c.fill({p for p in spine if p[0] > 60}, WHITE)
	draw_tail(c, [(70, 18), (76, 11), (75, 4), (69, 2)], 3.0, 72, 7)
	# Legs splayed wide: a crawl that squeezes through a window.
	draw_leg(c, 58, 32, 53, 43, 3.5, 5, 2.5)
	draw_leg(c, 69, 30, 75, 43, 3.5, 5, 2.5)
	draw_leg(c, 15, 33, 7, 43, 3.5, 5, 2.5)
	draw_leg(c, 33, 33, 41, 43, 3.5, 5, 2.5)
	head = c.mask(ellipse(hx, hy, hrx, hry))
	c.part(head, YEL, YEL_SH, YEL_HI, light(hx, hy, hrx, hry), 0.5, -0.85)
	c.fill({(x, y) for x, y in body if abs(x - hx) <= 2 and y < hy - hry + 1}, WHITE_HI)
	draw_face(c, head, hx, hy, hrx, hry, eye_dx=7, eye_ry=2, stripe_w=5,
		mouth_cy=34, mouth_rx=9, mouth_ry=3, tongue_cy=39, tongue_rx=5, tongue_ry=7,
		ear_pts=[[(11, 18), (14, 6), (21, 16)], [(27, 16), (34, 5), (37, 18)]])
	return c


def check(im: Image.Image, name: str, size: tuple[int, int]) -> None:
	cols = set(im.getdata())
	alphas = {p[3] for p in cols}
	ok = im.size == size and alphas <= {0, 255} and len(cols) <= 32
	print(f"{name}: {im.size[0]}x{im.size[1]} colours {len(cols)} alpha {sorted(alphas)}"
		f" {'OK' if ok else 'FAIL'}")
	if not ok:
		raise SystemExit(1)


def main() -> None:
	ap = argparse.ArgumentParser()
	ap.add_argument("--preview", help="folder for 6x nearest previews")
	ap.add_argument("--out", help="write the PNGs here instead of scenes/enemies")
	args = ap.parse_args()
	out = Path(args.out) if args.out else OUT
	out.mkdir(parents=True, exist_ok=True)
	for name, drawer, size in (("door_raider", draw_fat_beast, FAT_SIZE),
			("agile_raider", draw_crawler, CRAWLER_SIZE)):
		im = drawer().save(out / f"{name}.png")
		check(im, name, size)
		if args.preview:
			Path(args.preview).mkdir(parents=True, exist_ok=True)
			big = im.resize((im.size[0] * 6, im.size[1] * 6), Image.NEAREST)
			big.save(Path(args.preview) / f"{name}_x6.png")


if __name__ == "__main__":
	main()
