"""Draw the two base raider sprites (door and window raider) as flat pixel art.

Owner's design (2026-10-01, second pass): creepy, not cute, Darkest Dungeon
dark. The door raider is a humanoid gone feral: a hunched loper whose head
hangs forward out of a furred ruff, tapered arms longer than the legs with
the claws on the van floor, hair that trails every bob, knobbed spine,
hanging jaw, corpse-grey skin and black eye pits, nothing bright. The loper is both the door raider and the window
raider. door_raider.png is a 13-frame 832 x 320 sheet: row 0 the 13-frame run (a bounding charge,
seen from the front; frame 0 is the still), row 1 the 5-frame jump take-off, row 2 a 4-frame
front-on latch onto the van wall (reach, impact, cling), row 3 an 8-frame front-on wall crawl
(diagonal pairs, looping). Every frame has the
feral face (draw_feral_head), riding the pose's head bob and jaw lag.

Art rules (.claude/rules/art-style.md, pixel art): native size, one image
pixel = one art pixel at pixel_size 0.024 (2.4 cm); flat colours, no
anti-aliasing, alpha 0 or 255; hard shadows lit from the upper left (base,
one shadow, one highlight per material); a hard one-pixel outline.

Every shape is a predicate over integer pixels, so the drawing is exact and
deterministic. Usage:

    py -3 tools/gen_enemy_sprites.py              # writes scenes/enemies/*.png
    py -3 tools/gen_enemy_sprites.py --preview D  # also 6x previews in D
    py -3 tools/gen_enemy_sprites.py --out D      # draft somewhere else first
    py -3 tools/gen_enemy_sprites.py --strip P    # run 0, latch and climb frames in one 6x PNG
"""
from __future__ import annotations

import argparse
import math
import random
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "scenes" / "enemies"

# Canvas size: the loper (door and window raider) is 1.54 x 1.92 m.
LOPER_SIZE = (64, 80)
LOPER_FRAMES = 13
LOPER_ROWS = 4
JUMP_FRAMES = 5
LATCH_FRAMES = 4
CLIMB_FRAMES = 8
LOPER_SHEET = (LOPER_SIZE[0] * LOPER_FRAMES, LOPER_SIZE[1] * LOPER_ROWS)

OUTLINE = (30, 20, 18)

# The loper: corpse grey-green, every tone inside the art rules' albedo budget
# (skin 0.03..0.15 linear, the bone and teeth highlights under 0.35), so the
# sprite reads as a shape the dark swallows, never a bright cut-out.
SKIN_HI = (104, 110, 96)
SKIN = (72, 78, 68)
SKIN_SH = (42, 46, 40)
SKIN_DEEP = (24, 27, 24)
BONE_HI = (138, 130, 112)
BONE = (98, 92, 78)
PIT = (6, 5, 6)
GLINT = (150, 158, 140)
TEETH = (164, 156, 134)
GUM = (46, 12, 14)
BLOOD = (96, 20, 16)
BLOOD_DARK = (54, 10, 8)
CLAW = (26, 23, 21)
CLAW_TIP = (112, 44, 30)
# soot black-brown fur: base, shadow, highlight, inside the albedo budget
FUR_HI = (64, 53, 42)
FUR = (42, 34, 28)
FUR_SH = (25, 21, 18)

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

	def blit(self, src: "Canvas", dx: int, dy: int = 0) -> None:
		"""Copy src's opaque pixels over this canvas, shifted; set() clips the rest."""
		for y in range(src.h):
			for x in range(src.w):
				c = src.px[y][x]
				if c is not None:
					self.set(x + dx, y + dy, c)

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


def either(*preds):
	"""Union of predicates."""
	return lambda x, y: any(p(x, y) for p in preds)


def minus(a, b):
	"""Points in a that are not in b."""
	return lambda x, y: a(x, y) and not b(x, y)


def taper(points, radii):
	"""Muscle that thins toward the wrist or ankle, so a limb is one tapered shape,
	not a ball on a stick."""
	return either(*[capsule(*points[i], *points[i + 1], radii[i], radii[i + 1])
		for i in range(len(points) - 1)])


def fur_fringe(c: Canvas, m, seed, sway=(0, 0), length=3, density=0.55,
		up_only=False) -> None:
	"""Hair tufts along the outside edge of mask m: dark jagged hair on the outline.

	The same seed draws the same tuft roots and lengths every frame; only sway moves
	the tips."""
	rng = random.Random(seed)
	cx = sum(p[0] for p in m) / len(m)
	cy = sum(p[1] for p in m) / len(m)
	for x, y in sorted(m):
		outs = [(dx, dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
			if (x + dx, y + dy) not in m and not (up_only and dy == 1)]
		if not outs:
			continue
		if rng.random() >= density:
			continue
		n = max(1, length + rng.randint(-1, 1))
		d = outs[rng.randrange(len(outs))]
		ox, oy = x - cx, y - cy
		norm = math.hypot(ox, oy) or 1.0
		nx = (ox / norm + d[0]) / 2
		ny = (oy / norm + d[1]) / 2
		prev = (x, y)
		for i in range(1, n + 1):
			t = i / n
			px = round(x + nx * i * 1.5 + sway[0] * t)
			py = round(y + ny * i * 1.5 + sway[1] * t)
			if (px, py) in m or (px, py) == prev:
				continue
			c.set(px, py, OUTLINE if i == n else FUR_SH)
			prev = (px, py)
		if (x, y) in m:
			c.set(x, y, FUR_SH)


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


def draw_claws(c: Canvas, wx: int, wy: int, tips) -> None:
	"""Fingers fanning from a wrist (or ankle) to the floor, each ending in a nail."""
	for tx, ty in tips:
		finger = c.mask(capsule(wx, wy, tx, ty, 1.6, 1.1))
		c.part(finger, SKIN_SH, SKIN_DEEP, SKIN, light(tx, ty, 6, 6), 0.3, -1.2)
		nail = c.mask(capsule(wx + (tx - wx) * 0.6, wy + (ty - wy) * 0.6, tx, ty, 1.0, 0.8))
		c.fill(nail, CLAW)
		c.set(tx, ty, CLAW_TIP)


def draw_strand(c: Canvas, x0: int, y0: int, x1: int, y1: int) -> None:
	"""A one-pixel lank of hair, dark on whatever it hangs over."""
	c.fill(c.mask(capsule(x0, y0, x1, y1, 0.6)), OUTLINE)


def draw_rump(c: Canvas, cy: int, rx: float, ry: float, tail, sway=(0, 0),
		flare: int = 0) -> None:
	"""Two furred haunch lobes and the tail-bone knobs, seen over the dropped hump."""
	for cx in (27, 37):
		lobe = c.mask(ellipse(cx, cy, rx, ry))
		c.part(lobe, FUR, FUR_SH, FUR_HI, light(cx, cy, rx, ry), 0.25, -1.0)
		fur_fringe(c, lobe, seed=41, sway=sway, length=2 + flare, up_only=True)
	for r in tail:
		knob = c.mask(ellipse(32, r, 1.6, 1.4))
		c.outline(knob)
		c.fill(knob, BONE)
		c.fill({p for p in knob if p[0] <= 31 and p[1] <= r}, BONE_HI)


def draw_sole(c: Canvas, cx: int, cy: int) -> None:
	"""A hind foot seen sole-on, claws up: darker than the skin so it reads as an underside."""
	sole = c.mask(ellipse(cx, cy, 4.5, 5))
	c.part(sole, SKIN_SH, SKIN_DEEP, SKIN, light(cx, cy, 4.5, 5), 0.3, -1.2)
	c.fill(c.mask(ellipse(cx, cy + 2, 2.0, 1.5)), SKIN_DEEP)
	for tx, ty in ((cx - 2, cy - 2), (cx, cy - 3), (cx + 2, cy - 2)):
		c.set(tx, ty, SKIN_DEEP)
	draw_claws(c, cx, cy - 3, [(cx - 3, cy - 9), (cx, cy - 10), (cx + 3, cy - 9)])


# One pose per run frame, frame 0 being the approved still. The bound: both front paws
# lift and tuck together, the hind legs carry the body, something always touches row 79.
# by: the body's rise (negative is up; it carries the torso, shoulders, arms, head and
# drips); hump_dy / head_dy: extra y for the spine hump and the skull on top of by (the
# hump may rise at most 5 px net, its top knob sits on row 5); shoulder_dx: how far the
# shoulders, the arms' roots and the tear spread apart; lag: extra y for the hanging
# jaw, the chin blood and the strand ends, which trail the head; left/right: (elbow, wrist,
# claw tips) per arm; legs: ((knee, foot) left, (knee, foot) right) as absolute points.
# rump: (cy, rx, ry, tail), two lobes at x 27 and x 37 on row cy, tail the rows of the
# tail-bone knobs at x 32 (absolute rows, never shifted by by); soles: each leg's foot is
# the ankle and a hind sole with its claws up is drawn 5 px above it, not the floor claws.
# Frame 0 still. Frame 1 crouch: hips down, knees wide, head low. Frame 2 push: hind legs
# straight under the body, hump at its highest, the head still low (it trails the body).
# Frame 3 paws-rise: both paws half lifted, hind feet planted. Frame 4 lift-off: paws tuck
# under the chest, left toes still on the floor, the rump starting to show over the dropped
# hump. Frame 5 tip-over: the left hind foot pushes off the floor, the right leg swings up
# behind, the head dropping. Frame 6 kick: airborne but low, the head dropped 14 px to the
# chest, the two-lobed rump and tail-bone above the hump, both hind feet sole-on at the top
# corners, claws up. Frame 7 fall: still airborne, the head still dropping, the paws reaching
# down. Frame 8 drop: claws 2 px off the floor, the hind feet coming down under the rump.
# Frame 9 reach: first contact, paws wide, the rump still high, the body barely down. Frame 10
# rump-down: the lowest body and head, the rump sinks behind the hump onto the hind legs, the
# shoulders spread and the elbows bowed out. Frame 11 land: paws flat, the body settling, the
# head recovering. Frame 12 gather: the still's shape with the body 2 px low.
LOPER_POSES = [
	dict(by=0, hump_dy=0, head_dy=0, shoulder_dx=0, lag=0,
		left=((4, 43), (8, 71), [(2, 79), (6, 79), (10, 79), (14, 78)]),
		right=((60, 48), (57, 73), [(52, 78), (56, 79), (60, 79), (63, 77)]),
		legs=(((16, 66), (19, 75)), ((48, 67), (45, 75)))),
	dict(by=3, hump_dy=-1, head_dy=3, shoulder_dx=1, lag=1,  # 1 crouch
		left=((2, 49), (9, 72), [(3, 79), (7, 79), (11, 79), (15, 78)]),
		right=((62, 53), (56, 74), [(51, 78), (55, 79), (59, 79), (63, 78)]),
		legs=(((12, 69), (19, 75)), ((52, 70), (45, 75)))),
	dict(by=-2, hump_dy=-2, head_dy=2, shoulder_dx=0, lag=1,  # 2 push
		left=((5, 41), (8, 70), [(2, 79), (6, 79), (10, 79), (14, 78)]),
		right=((59, 45), (57, 72), [(52, 78), (56, 79), (60, 79), (63, 77)]),
		legs=(((22, 65), (20, 75)), ((42, 66), (44, 75)))),
	dict(by=-4, hump_dy=2, head_dy=2, shoulder_dx=0, lag=2,  # 3 paws-rise
		left=((4, 38), (11, 61), [(6, 67), (9, 69), (13, 69), (16, 67)]),
		right=((60, 41), (54, 63), [(49, 68), (52, 70), (55, 70), (58, 68)]),
		legs=(((20, 64), (20, 75)), ((44, 63), (45, 75)))),
	dict(by=-5, hump_dy=5, head_dy=4, shoulder_dx=-1, lag=2,  # 4 lift-off
		left=((3, 35), (14, 52), [(10, 56), (13, 58), (16, 58), (18, 56)]),
		right=((61, 37), (50, 54), [(46, 58), (49, 60), (52, 60), (54, 58)]),
		legs=(((17, 63), (19, 75)), ((47, 59), (46, 67))), rump=(6, 7, 5, ())),
	dict(by=-5, hump_dy=7, head_dy=9, shoulder_dx=-1, lag=3,  # 5 tip-over
		left=((4, 40), (11, 59), [(6, 65), (9, 67), (13, 67), (16, 65)]),
		right=((61, 42), (53, 61), [(48, 66), (51, 68), (54, 68), (57, 66)]),
		legs=(((18, 62), (19, 75)), ((50, 45), (55, 34))), rump=(8, 8, 6, (4, 6))),
	dict(by=-5, hump_dy=10, head_dy=14, shoulder_dx=0, lag=4,  # 6 kick, airborne
		left=((5, 44), (9, 65), [(3, 72), (7, 74), (11, 74), (15, 72)]),
		right=((61, 47), (56, 67), [(50, 72), (54, 74), (58, 74), (62, 72)]),
		legs=(((10, 30), (5, 15)), ((54, 31), (59, 16))), rump=(10, 8, 7, (2, 4, 6)),
		soles=True),
	dict(by=-4, hump_dy=9, head_dy=14, shoulder_dx=1, lag=4,  # 7 fall, airborne
		left=((4, 44), (8, 66), [(2, 73), (6, 75), (10, 75), (14, 73)]),
		right=((62, 47), (57, 68), [(51, 73), (55, 75), (59, 75), (63, 73)]),
		legs=(((9, 34), (7, 23)), ((55, 35), (57, 24))), rump=(10, 8, 7, (3, 5, 7)),
		soles=True),
	dict(by=-3, hump_dy=8, head_dy=13, shoulder_dx=2, lag=3,  # 8 drop, airborne
		left=((2, 43), (7, 65), [(1, 74), (5, 76), (9, 76), (13, 75)]),
		right=((63, 46), (58, 67), [(52, 74), (56, 76), (60, 76), (63, 75)]),
		legs=(((9, 41), (10, 30)), ((55, 42), (54, 31))), rump=(10, 8, 7, (4, 6))),
	dict(by=-1, hump_dy=5, head_dy=12, shoulder_dx=3, lag=3,  # 9 reach
		left=((1, 43), (6, 68), [(1, 77), (4, 78), (8, 79), (12, 78)]),
		right=((63, 46), (58, 70), [(53, 78), (57, 79), (61, 79), (63, 78)]),
		legs=(((10, 48), (13, 57)), ((54, 49), (51, 58))), rump=(10, 8, 6, (5, 7))),
	dict(by=3, hump_dy=2, head_dy=10, shoulder_dx=4, lag=4,  # 10 rump-down
		left=((0, 49), (7, 70), [(1, 78), (5, 79), (9, 79), (13, 79)]),
		right=((63, 52), (58, 72), [(52, 79), (56, 79), (60, 79), (63, 78)]),
		legs=(((12, 55), (15, 63)), ((52, 56), (49, 64))), rump=(11, 8, 5, (7,))),
	dict(by=4, hump_dy=0, head_dy=8, shoulder_dx=3, lag=3,  # 11 land
		left=((2, 50), (8, 72), [(2, 79), (6, 79), (10, 79), (14, 79)]),
		right=((62, 53), (57, 74), [(52, 79), (56, 79), (60, 79), (63, 79)]),
		legs=(((14, 61), (17, 69)), ((50, 62), (47, 70)))),
	dict(by=2, hump_dy=-1, head_dy=4, shoulder_dx=1, lag=2,  # 12 gather
		left=((3, 48), (8, 72), [(2, 79), (6, 79), (10, 79), (14, 78)]),
		right=((61, 52), (57, 74), [(52, 78), (56, 79), (60, 79), (63, 78)]),
		legs=(((14, 67), (19, 75)), ((50, 68), (45, 75)))),
]
assert len(LOPER_POSES) == LOPER_FRAMES

# Row 1 of the sheet: the jump, front-on like the run (the sprite is never flipped). Same
# pose format as the run table; bx is left out (0), the body stays centred (draw_loper still
# supports it). It is the run's rising half (frames 0 to 6) with the body higher and the
# limbs thrown out further, and the same limits: the hump rises at most 5 px net.
# Frame 0 crouch: run frame 1 deeper, hips low, knees wide, head low, elbows bowed out, claws
# on row 79. Frame 1 push: run frame 2 stronger, body up, hind legs straight under it, arms
# stretched long with claws still on row 79. Frame 2 paws-rise: run frame 3 more extreme, both
# paws lifted high and wide, hind feet planted. Frame 3 lift-off: run frame 4 pushed on, paws
# tucked high under the chest, rump showing, left toes the last thing on the floor. Frame 4
# airborne: run frame 6 (kick) pushed on, held for the rest of the jump; body highest, both
# hind feet sole-on at the top corners, rump and tail-bone above the hump, paws reaching
# down and out, nothing on row 79.
LOPER_JUMP_POSES = [
	dict(by=6, hump_dy=-2, head_dy=4, shoulder_dx=2, lag=1,  # 0 crouch
		left=((0, 52), (8, 73), [(2, 79), (6, 79), (10, 79), (14, 78)]),
		right=((63, 56), (56, 75), [(51, 78), (55, 79), (59, 79), (63, 78)]),
		legs=(((9, 71), (19, 75)), ((55, 72), (45, 75)))),
	dict(by=-4, hump_dy=-1, head_dy=2, shoulder_dx=0, lag=1,  # 1 push
		left=((5, 38), (8, 71), [(2, 79), (6, 79), (10, 79), (14, 78)]),
		right=((59, 42), (57, 72), [(52, 78), (56, 79), (60, 79), (63, 77)]),
		legs=(((21, 66), (20, 75)), ((43, 67), (44, 75)))),
	dict(by=-7, hump_dy=2, head_dy=2, shoulder_dx=1, lag=2,  # 2 paws-rise
		left=((3, 36), (6, 54), [(1, 60), (4, 62), (8, 62), (11, 60)]),
		right=((61, 38), (58, 55), [(53, 61), (56, 63), (60, 63), (63, 61)]),
		legs=(((20, 63), (20, 75)), ((44, 62), (45, 75)))),
	dict(by=-9, hump_dy=4, head_dy=4, shoulder_dx=-1, lag=2,  # 3 lift-off
		left=((3, 31), (15, 46), [(11, 50), (14, 52), (17, 52), (19, 50)]),
		right=((61, 33), (49, 47), [(45, 51), (48, 53), (51, 53), (53, 51)]),
		legs=(((17, 62), (19, 75)), ((47, 56), (46, 64))), rump=(6, 7, 5, ())),
	dict(by=-10, hump_dy=5, head_dy=14, shoulder_dx=0, lag=4,  # 4 airborne
		left=((4, 38), (7, 58), [(2, 65), (6, 67), (10, 67), (14, 65)]),
		right=((60, 40), (57, 60), [(50, 65), (54, 67), (58, 67), (62, 65)]),
		legs=(((7, 26), (3, 11)), ((57, 27), (61, 12))), rump=(8, 8, 7, (1, 3, 5)),
		soles=True),
]
assert len(LOPER_JUMP_POSES) == JUMP_FRAMES

# Row 2 of the sheet: the latch onto the van wall, front-on. The player is inside the van
# looking out through the glass at the wall; the loper arrives from outside and ends pressed
# flat on it, belly to the camera, face straight at it, all four limbs splayed in an X with
# claws hooked in (a gecko on a window). Continues from jump frame 4 (airborne, soles up).
# Frame 0 reach: stretch, paws thrown up to the upper corners, hind legs swinging down.
# Frame 1 impact: squash, the widest X, head sunk into the shoulders. Frame 2 pull in: elbows
# bent out, paws drawn in. Frame 3 cling: held, head raised, claws curled, right arm higher.
LOPER_LATCH_POSES = [
	dict(by=-8, hump_dy=2, head_dy=6, shoulder_dx=0, lag=2,  # 0 reach
		left=((6, 24), (5, 12), [(2, 7), (4, 5), (7, 5), (10, 7)]),
		right=((57, 25), (58, 13), [(61, 8), (59, 6), (56, 6), (53, 8)]),
		legs=(((10, 50), (5, 60)), ((54, 51), (59, 61))), soles=True),
	dict(by=-2, hump_dy=-1, head_dy=1, shoulder_dx=3, lag=1,  # 1 impact
		left=((3, 26), (2, 15), [(0, 10), (2, 8), (5, 7), (8, 8)]),
		right=((60, 26), (61, 15), [(63, 10), (61, 8), (58, 7), (55, 8)]),
		legs=(((6, 64), (2, 74)), ((58, 65), (62, 75))), soles=True),
	dict(by=-3, hump_dy=0, head_dy=-1, shoulder_dx=2, lag=1,  # 2 pull in
		left=((4, 28), (5, 17), [(2, 12), (4, 10), (7, 10), (10, 12)]),
		right=((59, 29), (58, 18), [(61, 13), (59, 11), (56, 11), (53, 13)]),
		legs=(((7, 63), (6, 74)), ((57, 64), (58, 75))), soles=True),
	dict(by=-3, hump_dy=0, head_dy=-2, shoulder_dx=2, lag=1,  # 3 cling
		left=((4, 28), (5, 17), [(2, 13), (4, 11), (7, 11), (10, 13)]),
		right=((59, 28), (58, 17), [(61, 13), (59, 11), (56, 11), (53, 13)]),
		legs=(((7, 63), (6, 74)), ((57, 64), (58, 75))), soles=True),
]
assert len(LOPER_LATCH_POSES) == LATCH_FRAMES

# Row 3 of the sheet: the wall crawl, front-on like the latch (never a side view, never flipped
# per side). Every frame edits the cling pose: belly to the camera, limbs in an X, elbows and
# knees bent out, head up and bobbing 1 px against the body. Gait in diagonal pairs, like a
# gecko up a wall: frames 0-3 the LEFT fore paw and RIGHT hind foot travel up while the RIGHT
# fore paw and LEFT hind foot stay planted and drag down as the body rises; frames 4-7 the same
# mirrored (RIGHT fore, LEFT hind), with the cling pose's 1 px asymmetry kept, not pixel-mirrored.
# Frame 0 end of the push (the travelling paw 2 px low). Frame 1 paw lifting: wrist and claw
# tips 5 px up, claws curled (1 px apart) off the wall, hind foot 4 px up. Frame 2 paw at its
# highest (10 px above cling, tips on row 2), foot 8 px up, body 1 px up, shoulders 1 px wider.
# Frame 3 paw planted, claws fanned wide again, body 2 px above frame 0, the other paw 4 px
# low. Frame 7 flows back into frame 0.
LOPER_CLIMB_POSES = [
	dict(by=-3, hump_dy=0, head_dy=-2, shoulder_dx=2, lag=1,  # 0 push end, left paw low
		left=((4, 30), (5, 19), [(2, 15), (4, 13), (7, 13), (10, 15)]),
		right=((59, 28), (58, 17), [(61, 13), (59, 11), (56, 11), (53, 13)]),
		legs=(((7, 63), (6, 74)), ((57, 64), (58, 75))), soles=True),
	dict(by=-3, hump_dy=0, head_dy=-1, shoulder_dx=2, lag=1,  # 1 left paw lifting
		left=((4, 26), (5, 12), [(4, 8), (5, 6), (6, 6), (7, 8)]),
		right=((59, 28), (58, 17), [(61, 13), (59, 11), (56, 11), (53, 13)]),
		legs=(((7, 63), (6, 74)), ((57, 60), (58, 71))), soles=True),
	dict(by=-4, hump_dy=0, head_dy=-2, shoulder_dx=3, lag=1,  # 2 left paw highest
		left=((3, 23), (5, 7), [(4, 3), (5, 2), (6, 2), (7, 3)]),
		right=((59, 29), (58, 18), [(61, 14), (59, 12), (56, 12), (53, 14)]),
		legs=(((7, 64), (6, 75)), ((57, 56), (58, 67))), soles=True),
	dict(by=-5, hump_dy=0, head_dy=-3, shoulder_dx=2, lag=1,  # 3 left paw planted, body up
		left=((4, 28), (5, 17), [(2, 13), (4, 11), (7, 11), (10, 13)]),
		right=((59, 32), (58, 21), [(61, 17), (59, 15), (56, 15), (53, 17)]),
		legs=(((7, 65), (6, 76)), ((57, 64), (58, 75))), soles=True),
	dict(by=-3, hump_dy=0, head_dy=-2, shoulder_dx=2, lag=1,  # 4 push end, right paw low
		left=((4, 28), (5, 17), [(2, 13), (4, 11), (7, 11), (10, 13)]),
		right=((59, 30), (58, 19), [(61, 15), (59, 13), (56, 13), (53, 15)]),
		legs=(((7, 63), (6, 74)), ((57, 64), (58, 75))), soles=True),
	dict(by=-3, hump_dy=0, head_dy=-1, shoulder_dx=2, lag=1,  # 5 right paw lifting
		left=((4, 28), (5, 17), [(2, 13), (4, 11), (7, 11), (10, 13)]),
		right=((59, 26), (58, 12), [(59, 8), (58, 6), (57, 6), (56, 8)]),
		legs=(((7, 59), (6, 70)), ((57, 64), (58, 75))), soles=True),
	dict(by=-4, hump_dy=0, head_dy=-2, shoulder_dx=3, lag=1,  # 6 right paw highest
		left=((4, 29), (5, 18), [(2, 14), (4, 12), (7, 12), (10, 14)]),
		right=((60, 23), (58, 7), [(59, 3), (58, 2), (57, 2), (56, 3)]),
		legs=(((7, 55), (6, 66)), ((57, 65), (58, 76))), soles=True),
	dict(by=-5, hump_dy=0, head_dy=-3, shoulder_dx=2, lag=1,  # 7 right paw planted, body up
		left=((4, 32), (5, 21), [(2, 17), (4, 15), (7, 15), (10, 17)]),
		right=((59, 28), (58, 17), [(61, 13), (59, 11), (56, 11), (53, 13)]),
		legs=(((7, 63), (6, 74)), ((57, 66), (58, 77))), soles=True),
]
assert len(LOPER_CLIMB_POSES) == CLIMB_FRAMES


def fur_sway(frame: int, poses=LOPER_POSES) -> tuple[int, int]:
	"""Overlap and follow-through: the hair lags the body by a frame."""
	# the jump row starts from the run's still, not from its own last frame; the climb loops
	prev = LOPER_POSES[0] if poses is not LOPER_POSES and frame == 0 else poses[frame - 1]
	if poses is LOPER_CLIMB_POSES and frame == 0:
		prev = poses[-1]
	vy = poses[frame]["by"] - prev["by"]
	return 0, max(-3, min(3, -vy))


# The feral face on every run frame (owner, 2026-10-03): the skull keeps the dark corpse skin, and the pale
# FACE tones only trace its edge (the lit left side, the chin, the cheekbone and jaw-hinge
# points), so the player reads where the head (the head hitbox, rows 18-48) starts and ends
# from as few bright pixels as possible; red eyes and a red-gummed maw of needle fangs make
# it read as a monster, not a cartoon.
FACE_HI = (176, 172, 150)
FACE = (134, 132, 114)
FACE_SH = (88, 90, 78)
EYE_RED = (214, 30, 22)
EYE_HOT = (255, 214, 120)
DROOL = (150, 160, 140)


def draw_fang(c: Canvas, x: int, y: int, w: int, length: int, lean: int = 0,
		up: bool = False) -> None:
	"""One tapered fang: a root w pixels wide at row y narrowing to a one-pixel point
	length rows away (down, or up for the lower jaw), the tip leaning lean pixels; the
	right half is in shadow, since the light comes from the upper left."""
	for i in range(length):
		t = i / max(1, length - 1)
		half = (w - 1) * (1.0 - t) / 2.0
		cx = x + (w - 1) / 2.0 + lean * t * t
		row = y - i if up else y + i
		for xx in range(round(cx - half), round(cx + half) + 1):
			c.set(xx, row, WHITE_SH if w > 1 and xx > cx else TEETH)


def draw_feral_head(c: Canvas, hd: int, jy: int, by: int, bx: int = 0) -> None:
	"""The feral head for every run frame: a long, angular, tilted skull with sharp
	cheekbones and hollow cheeks, a V brow over slanted black sockets with burning red
	eyes, a bare nasal pit, and a maw split almost ear to ear, red gums peeled back over
	uneven needle fangs, the lower jaw hanging open with its fangs up and drool between."""
	head = Canvas(LOPER_SIZE)
	skull = head.mask(polygon([(25, 19), (30, 17), (36, 17), (40, 19), (44, 23), (47, 29),
		(43, 33), (44, 38), (40, 42), (24, 41), (20, 37), (21, 33), (17, 29), (21, 22)]))
	head.part(skull, SKIN, SKIN_SH, SKIN_HI, light(29, 24, 13, 14), 0.25, -0.95)
	# Matted hair cap over the crown, hanging onto the brow in jagged locks, so the
	# skull reads long and narrow instead of a bald dome.
	cap = head.mask(polygon([(19, 24), (22, 17), (30, 13), (37, 14), (44, 18), (46, 25),
		(42, 21), (40, 24), (37, 20), (34, 23), (31, 19), (28, 23), (25, 20), (22, 25)]))
	head.part(cap, FUR, FUR_SH, FUR_HI, light(30, 18, 14, 6), 0.3, -0.9)
	# Hollow cheeks under the cheekbones.
	for pts in (((21, 31), (26, 30), (25, 36), (21, 36)),
			((38, 31), (43, 31), (42, 37), (38, 36))):
		head.fill(head.mask(polygon(pts)), SKIN_DEEP)
	# The brow: a hard V pointing down at the nose, the sockets slanted under it.
	head.fill(head.mask(polyline([(20, 22), (31, 26), (44, 21)], 1.1)), SKIN_DEEP)
	head.fill(head.mask(polygon([(21, 24), (30, 27), (29, 30), (22, 28)])), PIT)
	head.fill(head.mask(polygon([(33, 27), (43, 23), (43, 28), (35, 30)])), PIT)
	# Eyes: a red iris with one hot pixel, the right one a pixel lower (the head tilts).
	for ex, ey in ((26, 27), (38, 27)):
		for dx in (-1, 0, 1):
			head.set(ex + dx, ey, EYE_RED)
		head.set(ex, ey + 1, EYE_RED)
		head.set(ex, ey, EYE_HOT)
	# Nasal pit and two slits, no nose.
	head.fill(head.mask(polygon([(30, 30), (34, 30), (32, 34)])), PIT)
	# The maw: lips peeled back almost ear to ear, red gum along the top, black throat.
	# Its corners run up into the cheeks, past where a mouth should stop.
	maw = head.mask(polygon([(19, 32), (21, 33), (25, 35), (31, 36), (38, 35), (43, 33),
		(46, 31), (44, 35), (40, 47), (25, 47), (21, 36)]))
	head.outline(maw)
	head.fill(maw, PIT)
	head.fill({p for p in maw if p[1] <= 37}, GUM)
	head.fill({p for p in maw if 41 <= p[1] and 26 <= p[0] <= 39}, MOUTH)
	# Upper fangs: tapered and hooked, two long canines, the rest short and uneven.
	for x, w, length, lean in ((21, 2, 3, 1), (24, 3, 7, 1), (29, 2, 4, 0), (34, 2, 3, 0),
			(37, 3, 8, -1), (42, 2, 3, -1)):
		draw_fang(head, x, 36, w, length, lean)
	# Drool hanging between the fangs.
	for x, y0, y1 in ((27, 38, 45), (35, 39, 46)):
		for y in range(y0, y1):
			head.set(x, y, DROOL)
	# The rim follows the light from the upper left like every other part: pale only on
	# the edges that face up or left (the left temple and cheek, the top of the left
	# cheekbone). Edges facing down or right stay dark.
	face = skull - cap - maw
	lit = light(31, 30, 14, 12)
	for x, y in face:
		if y < 23 or lit(x, y) > -0.25:
			continue
		if (x - 1, y) not in skull or (x, y - 1) not in skull:
			head.set(x, y, FACE_HI)
	c.blit(head, bx, hd)
	# Matted hair framing the skull, kept off the face so it stays one pale shape.
	for x0, y0, x1, y1 in ((21, 19, 16, 31), (19, 23, 15, 34), (43, 19, 47, 31)):
		draw_strand(c, x0 + bx, y0 + hd, x1 + bx, y1 + jy)
	# The lower jaw hangs open and a pixel to the left, its fangs pointing up, gum along its lip.
	jaw = Canvas(LOPER_SIZE)
	jaw_m = jaw.mask(polygon([(22, 46), (41, 46), (39, 51), (33, 58), (29, 58), (24, 51)]))
	jaw.part(jaw_m, SKIN, SKIN_SH, SKIN_HI, light(31, 50, 10, 7), 0.3, -1.2)
	# The jaw's left edge catches the light; its chin points down, away from it.
	for x, y in jaw_m:
		if (x - 1, y) not in jaw_m and y < 52:
			jaw.set(x, y, FACE)
	for x in range(23, 41):
		jaw.set(x, 46, GUM)
	for x, w, length, lean in ((22, 2, 3, 0), (28, 3, 6, 1), (33, 2, 3, 0), (40, 3, 6, -1)):
		draw_fang(jaw, x, 46, w, length, lean, up=True)
	for x, y in ((28, 53), (29, 54), (30, 55), (33, 53), (34, 54), (31, 56)):
		jaw.set(x, y, BLOOD_DARK)
	c.blit(jaw, -1 + bx, jy)
	for x, y0, y1 in ((29, 58, 61), (32, 58, 63), (30, 58, 59)):
		for y in range(y0 + by, y1 + by):
			c.set(x + bx, y, BLOOD_DARK)
		c.set(x + bx, y1 + by, BLOOD)


def draw_loper(frame: int = 0, poses=LOPER_POSES) -> Canvas:
	"""The door raider, seen from the front as it comes through the doors: the
	furred mantle rises above and behind the head, which hangs from a hair ruff,
	tapered arms with fur sleeves reach the floor, the tapered legs crouch behind,
	and the hair trails each bob (fur_sway). Feet on the bottom row. The parts are drawn
	at the still's coordinates on layers and blitted with the pose's bob, so every
	frame is the approved drawing moved, never redrawn. The bound is
	13 frames: still, crouch, push, paws-rise, lift-off, tip-over, kick, fall, drop,
	reach, rump-down, land, gather; frames 6, 7 and 8 are airborne (6 the kick)."""
	p = poses[frame]
	by = p["by"]
	bx = p.get("bx", 0)
	hy_ = by + p["hump_dy"]
	hd = by + p["head_dy"]
	sdx = p["shoulder_dx"]
	jy = hd + p["lag"]
	sway = fur_sway(frame, poses)
	flare = 1 if poses is LOPER_POSES and frame in (10, 11) else 0  # the coat flares when the weight lands
	c = Canvas(LOPER_SIZE)
	# Legs first, crouched behind everything: knees out, shins down, toes on the floor.
	# The pose holds each knee and foot as absolute points; only the hips ride the body.
	for hip, (knee, foot) in (((27 + bx, 56 + by), p["legs"][0]), ((37 + bx, 57 + by), p["legs"][1])):
		leg = c.mask(taper([hip, knee, foot], [4.5, 3.0, 2.2]))
		c.part(leg, SKIN_SH, SKIN_DEEP, SKIN, light(knee[0], knee[1], 12, 12), 0.2, -0.9)
		tuft = c.mask(ellipse(hip[0], hip[1] + 2, 4.5, 4.0))
		c.fill(tuft, FUR)
		fur_fringe(c, tuft, seed=31 + (hip[0] > 30), sway=sway, length=2 + flare,
			density=0.4)
		if p.get("soles"):
			draw_sole(c, foot[0], foot[1] - 5)
		else:
			draw_claws(c, foot[0], foot[1], [(foot[0] - 4, foot[1] + 4),
				(foot[0], foot[1] + 4), (foot[0] + 4, foot[1] + 4)])
	# The chest and belly in one shape from shoulder to hip, under the mantle: sparse
	# fur on the ribs, the belly bare and sunk.
	chest = c.mask(polygon([(22 + bx, 34 + by), (42 + bx, 34 + by), (40 + bx, 46 + by),
		(39 + bx, 58 + by), (25 + bx, 58 + by), (24 + bx, 46 + by)]))
	c.part(chest, FUR, FUR_SH, FUR_HI, light(32 + bx, 40 + by, 12, 14), 0.1, -1.0)
	c.fill({q for q in chest if q[1] >= 47 + by}, SKIN_SH)
	c.fill({q for q in chest if q[1] >= 56 + by}, SKIN_DEEP)
	for y in range(48 + by, 58 + by):
		c.set(32 + bx, y, SKIN_DEEP)
	for ry in (49, 53):
		for dx in range(1, 7):
			c.set(32 + bx - dx, ry + by + dx // 4, SKIN_DEEP)
			c.set(32 + bx + dx, ry + by + dx // 4, SKIN_DEEP)
	fur_fringe(c, chest, seed=12, sway=sway, length=2 + flare, density=0.35)
	# The mantle: shoulders, neck and the spine hump as one furred mass, the crest
	# above the head riding the hump, the shoulders the body, the right one lower.
	mantle_pts = [(5 - sdx, 28 + by), (7 - sdx, 21 + by), (14, 15 + hy_), (20, 10 + hy_),
		(27, 8 + hy_), (34, 8 + hy_), (44, 10 + hy_), (51, 15 + hy_), (58 + sdx, 23 + by),
		(60 + sdx, 31 + by), (50 + sdx, 34 + by), (44, 37 + by), (20, 36 + by),
		(14 - sdx, 34 + by)]
	mantle_pts = [(x + bx, y) for x, y in mantle_pts]
	mantle = c.mask(polygon(mantle_pts))
	c.part(mantle, FUR, FUR_SH, FUR_HI, light(32 + bx, 24 + by, 28, 16), 0.3, -0.9)
	# Mange: patches torn out of the coat, grey skin showing.
	for patch, tone in (
			([(16, 16 + hy_), (20, 15 + hy_), (21, 19 + hy_), (17, 20 + hy_)], SKIN),
			([(24, 14 + hy_), (28, 13 + hy_), (27, 17 + hy_)], SKIN_SH),
			([(10 - sdx, 26 + by), (14 - sdx, 25 + by), (15 - sdx, 29 + by),
				(11 - sdx, 30 + by)], SKIN_SH)):
		c.fill(c.mask(polygon([(x + bx, y) for x, y in patch])), tone)
	fur_fringe(c, mantle, seed=11, sway=sway, length=3 + flare, up_only=True)
	# Vertebrae poking through the fur along the crest.
	crest = ((20, 10), (27, 8), (34, 8), (44, 10))
	for kx, kr in ((22, 1.4), (26, 1.8), (31, 2.0), (36, 1.8), (41, 1.5)):
		i = 0 if kx < 27 else 1 if kx < 34 else 2
		(ax, ay), (bx_, bby) = crest[i], crest[i + 1]
		ky = ay + (bby - ay) * (kx - ax) / (bx_ - ax) + 1.0 + hy_
		knob = c.mask(ellipse(kx + bx, ky, kr, kr * 0.85))
		c.outline(knob)
		c.fill(knob, BONE)
		c.fill({q for q in knob if q[0] <= kx + bx - 1 and q[1] <= ky}, BONE_HI)
	# Skin torn open on the right shoulder, the fur ragged around it.
	tear = c.mask(polygon([(x + sdx + bx, y + by) for x, y in
		((44, 20), (50, 18), (53, 23), (48, 27), (43, 24))]))
	c.fill(tear, BLOOD_DARK)
	c.fill({q for q in tear if q[0] < 47 + sdx + bx and q[1] < 22 + by}, BLOOD)
	fur_fringe(c, tear, seed=13, sway=sway, length=1, density=0.5)
	# The haunches show over the dropped crest, so they are drawn after the mantle.
	if "rump" in p:
		draw_rump(c, *p["rump"], sway, flare)
	# Arms: one tapered limb from inside the mantle out to elbows wider than the body,
	# then down to the floor; bare skin forearm, a furred sleeve over the upper arm whose
	# hair hangs off the back of the arm.
	for shoulder, (elbow, wrist, tips), seed in (((14 - sdx + bx, 27 + by), p["left"], 21),
			((50 + sdx + bx, 29 + by), p["right"], 22)):
		arm = c.mask(taper([shoulder, elbow, wrist], [5.0, 3.4, 2.2]))
		c.part(arm, SKIN, SKIN_SH, SKIN_HI, light(elbow[0], elbow[1], 10, 24), 0.2, -0.95)
		past = (elbow[0] + (wrist[0] - elbow[0]) * 0.2, elbow[1] + (wrist[1] - elbow[1]) * 0.2)
		sleeve = c.mask(taper([shoulder, elbow, past], [5.5, 4.0, 3.2]))
		c.part(sleeve, FUR, FUR_SH, FUR_HI, light(elbow[0], elbow[1], 10, 24), 0.2, -0.95)
		back = {q for q in sleeve if (q[0] <= shoulder[0]) == (shoulder[0] < 32)}
		fur_fringe(c, back, seed=seed, sway=sway, length=3 + flare)
		draw_claws(c, wrist[0], wrist[1], tips)
	# The head hangs forward below the shoulders, tilted, in front of the chest:
	# a gaunt skull, a brow over black pits that look up at you, cheeks fallen in.
	# A ruff of hair behind and around the top of the skull, so the head hangs out of
	# the coat instead of floating on it.
	ruff = c.mask(polygon([(17 + bx, 34 + by), (18 + bx, 24 + hd),
		(22 + bx, 15 + hd), (32 + bx, 11 + hd), (42 + bx, 15 + hd), (46 + bx, 24 + hd),
		(47 + bx, 34 + by)]))
	c.fill(ruff, FUR_SH)
	fur_fringe(c, ruff, seed=51, sway=sway, length=2 + flare, density=0.45, up_only=True)
	draw_feral_head(c, hd, jy, by, bx)
	return c


def draw_loper_sheet() -> Canvas:
	"""Row 0 the thirteen run frames, row 1 the five jump take-off frames, row 2 the four
	latch frames, row 3 the eight climb frames, each cell exactly LOPER_SIZE."""
	sheet = Canvas(LOPER_SHEET)
	for i in range(LOPER_FRAMES):
		sheet.blit(draw_loper(i), i * LOPER_SIZE[0])
	for i in range(JUMP_FRAMES):
		sheet.blit(draw_loper(i, LOPER_JUMP_POSES), i * LOPER_SIZE[0], LOPER_SIZE[1])
	for i in range(LATCH_FRAMES):
		sheet.blit(draw_loper(i, LOPER_LATCH_POSES), i * LOPER_SIZE[0], LOPER_SIZE[1] * 2)
	for i in range(CLIMB_FRAMES):
		sheet.blit(draw_loper(i, LOPER_CLIMB_POSES), i * LOPER_SIZE[0], LOPER_SIZE[1] * 3)
	return sheet


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
	ap.add_argument("--strip", help="write one 6x PNG of run 0, latch and climb frames")
	args = ap.parse_args()
	out = Path(args.out) if args.out else OUT
	out.mkdir(parents=True, exist_ok=True)
	for name, drawer, size in (("door_raider", draw_loper_sheet, LOPER_SHEET),):
		im = drawer().save(out / f"{name}.png")
		check(im, name, size)
		if args.preview:
			Path(args.preview).mkdir(parents=True, exist_ok=True)
			big = im.resize((im.size[0] * 6, im.size[1] * 6), Image.NEAREST)
			big.save(Path(args.preview) / f"{name}_x6.png")
		if args.strip:
			write_strip(im, Path(args.strip))


def write_strip(sheet: Image.Image, path: Path) -> None:
	"""Run frame 0, the latch frames and the climb frames in one row at 6x, 2 px gaps."""
	w, h = LOPER_SIZE
	cells = [(0, 0)] + [(i, 2) for i in range(LATCH_FRAMES)] + [(i, 3) for i in range(CLIMB_FRAMES)]
	scale = 6
	gap = 2
	strip = Image.new("RGBA", (len(cells) * (w * scale + gap) - gap, h * scale), (40, 40, 40, 255))
	for n, (col, row) in enumerate(cells):
		cell = sheet.crop((col * w, row * h, (col + 1) * w, (row + 1) * h))
		cell = cell.resize((w * scale, h * scale), Image.NEAREST)
		strip.paste(cell, (n * (w * scale + gap), 0), cell)
	path.parent.mkdir(parents=True, exist_ok=True)
	strip.save(path)


if __name__ == "__main__":
	main()
