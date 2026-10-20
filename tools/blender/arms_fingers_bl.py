"""`arms.py step fingers`: zig-zags the four fingers sideways, mesh only (plan phase 5, D16-D20).

Runs through `arms_step_bl.py` (`prepare("fingers")` archives the parts, a re-run restores them).
Frame per finger: axial u along its `.01` bone, lat = the hand frame's lat (+ toward the thumb).
Each vertex has an axial position p from the `.01` head and a bone fraction t from p. The kink
sits at `.02` (index, ring, pinky) or `.03` (middle); the landing shear brings the tip pole back
to its own lateral position (D16). Webs blend their two fingers by lateral share. The left index
and ring are wrecked instead (D19, D20): no landing, then a joint bend about the `.03` head.
Each move is its own function `main` calls in order, so later moves can join the list.
"""
import math
import os
import sys

import bpy
import numpy as np
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import arms_step_bl as S  # noqa: E402
from arms_frame_bl import HandFrame  # noqa: E402

NAMES = ("index", "middle", "ring", "pinky")
ANGLE = {"index": 1.0, "middle": 0.7, "ring": 0.85, "pinky": 1.15}  # x 15 degrees
SIGN = {"index": 1.0, "middle": 1.0, "ring": 1.0, "pinky": -1.0}  # + toward the thumb
KINK3 = "middle"
KNUCKLE = {"index": 1.10, "middle": 1.08, "ring": 1.06, "pinky": 1.09}  # head swelling K (D9)
SKIRT = 3e-3  # skin this close to the finger tube lifts with the tube
KNUCKLE_R = 2.0 # swell reach in shafts: the skin over a head is 1.0-1.2 shaft away (D93)
GAIN = {"index": (0.04, 0.06), "middle": (0.06, 0.03), "ring": (0.03, 0.05),
        "pinky": (0.05, 0.02)}  # knot gain at `.02`, `.03` (D28, D32)
BASE_DEG = 15.0
WRECK_INDEX_DEG = 30.0
WRECK_RING_DEG = 40.0
SCALE = {"index": 1.0, "middle": 1.0, "ring": 1.0, "pinky": 1.0}  # fallback: a x 0.6 per finger
SIGN_FLIP = {}  # fallback: finger -> sign override


class Finger:
    """One finger's frame: u, bone lengths, joint positions along u, its tip pole."""

    def __init__(self, fr: HandFrame, name: str, parts: dict):
        b = "DEF-f_%s.0%d"
        h = [np.array(fr.head(b % (name, i))) for i in (1, 2, 3)]
        rig = bpy.data.objects["rig"]
        tail = np.array(rig.matrix_world @ rig.data.bones[b % (name, 3) + "." + fr.side].tail_local)
        self.name = name
        self.head = h
        self.u = (h[1] - h[0]) / np.linalg.norm(h[1] - h[0])
        self.L2 = float(np.linalg.norm(h[2] - h[1]))
        self.L3 = float(np.linalg.norm(tail - h[2]))
        self.pb = float((h[1] - h[0]) @ self.u)
        self.pc = float((h[2] - h[0]) @ self.u)
        self.pd = float((tail - h[0]) @ self.u)
        self.tan = math.tan(math.radians(BASE_DEG * ANGLE[name] * SCALE[name]))
        self.sign = SIGN_FLIP.get(name, SIGN[name])
        self.names = [b % (name, i) + "." + fr.side for i in (1, 2, 3)]
        self.land = True
        tube = parts["fingers"]
        sel = tube.wt(self.names[2]) > 0.5
        self.p_pole = float(((tube.co[sel] - h[0]) @ self.u).max())
        self.z_pole = float(self.z_raw(np.array([self.p_pole]))[0])
        lat = np.array(fr.lat)
        self.latf = lat - self.u * float(lat @ self.u)  # the finger's own lateral axis
        self.latf /= np.linalg.norm(self.latf)
        # Shaft: the mean ring radius over the middle of bone 1.
        p = (tube.co - h[0]) @ self.u
        mid = (tube.wt(self.names[0]) > 0.5) & (np.abs(p - 0.5 * self.pb) < 0.15 * self.pb)
        rv = tube.co[mid] - tube.co[mid].mean(axis=0)
        rv -= np.outer(rv @ self.u, self.u)
        self.shaft = float(np.linalg.norm(rv, axis=1).mean())
        # Joints: (axial position, g, convex side along latf). The kink bends toward `sign` at its
        # start and back at its end, so the convex side is opposite at `.02` and at `.03`.
        g2, g3 = GAIN[name]
        c2, c3 = (1.0, -self.sign) if name == KINK3 else (-self.sign, self.sign)
        self.joints = [(self.pb, g2, c2), (self.pc, g3, c3)]

    def z_raw(self, p: np.ndarray) -> np.ndarray:
        """Kinked lateral offset (metres, along the finger's own direction) at axial position p."""
        t2 = np.clip((p - self.pb) / (self.pc - self.pb), 0.0, 1.0)
        t3 = np.clip((p - self.pc) / (self.pd - self.pc), 0.0, 1.0)
        if self.name == KINK3:
            return self.tan * self.L3 * t3
        return np.where(p < self.pc, self.tan * t2 * self.L2, self.tan * (self.L2 - t3 * self.L3))

    def z(self, co: np.ndarray) -> np.ndarray:
        """Landed lateral offset for vertices at `co` (signed toward the thumb)."""
        p = (co - self.head[0]) @ self.u
        z = self.z_raw(p)
        if self.land:
            z = z - self.z_pole * np.maximum(p, 0.0) / self.p_pole
        return self.sign * z


def web_pairs(fr: HandFrame, fingers: list, co: np.ndarray) -> tuple:
    """Per web vertex: the index of its nearer finger pair's first finger and the lateral share
    (0 = first finger, 1 = second), by lat relative to the `.01` heads."""
    lat = np.array(fr.lat)
    heads = np.array([f.head[0] @ lat for f in fingers])  # ascending lat = pinky .. index
    x = co @ lat
    order = np.argsort(heads)
    hs = heads[order]
    k = np.clip(np.searchsorted(hs, x) - 1, 0, len(hs) - 2)
    share = np.clip((x - hs[k]) / (hs[k + 1] - hs[k]), 0.0, 1.0)
    return order[k], order[k + 1], share


def zigzag(parts: dict, fr: HandFrame, fingers: list) -> dict:
    """Move 1: the zig-zag with landed tips. Returns the new positions per part."""
    out = {}
    for key, part in parts.items():
        dv = np.zeros((len(part.co), 3))
        if key == "webs":
            a, b, share = web_pairs(fr, fingers, part.co)
            for i in range(len(part.co)):
                fa, fb = fingers[a[i]], fingers[b[i]]
                va = fa.z(part.co[i:i + 1])[0] * fa.latf
                vb = fb.z(part.co[i:i + 1])[0] * fb.latf
                dv[i] = va * (1.0 - share[i]) + vb * share[i]
            # Vertices shared with the fingers part take exactly the fingers' move (seam 0 mm).
            key_of = {tuple(np.round(c * 1e6).astype(np.int64)): i
                      for i, c in enumerate(parts["fingers"].co)}
            for i, c in enumerate(part.co):
                j = key_of.get(tuple(np.round(c * 1e6).astype(np.int64)))
                if j is not None:
                    dv[i] = out["fingers"][j] - parts["fingers"].co[j]
        else:
            for f in fingers:
                w = np.clip(part.wt(*f.names), 0.0, 1.0)
                dv += (w * f.z(part.co))[:, None] * f.latf[None, :]
        out[key] = part.co + dv
    return out


def smooth(x: np.ndarray) -> np.ndarray:
    """Smoothstep of x already scaled to 0..1."""
    t = np.clip(x, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def lift_field(p: np.ndarray, fingers: list, dors: np.ndarray) -> np.ndarray:
    """Dorsal knuckle lift at positions `p`: each head's h x (K - 1) x w summed and divided by
    max(1, sum w), so the field is continuous between heads and equals one head's lift where only
    that head reaches. w is 1 within 1.2 shaft of the head's column (offset less its dorsal part,
    as the hands measure takes it), fading to 0 at R = 2.0 shaft (D93), times smoothstep(0, 0.6
    shaft, h)."""
    num = np.zeros(len(p))
    den = np.zeros(len(p))
    for f in fingers:
        dv = p - f.head[0]
        h = dv @ dors
        col = np.linalg.norm(dv - np.outer(h, dors), axis=1)
        w = (1.0 - smooth((col - 1.2 * f.shaft) / ((KNUCKLE_R - 1.2) * f.shaft)))             * smooth(h / (0.6 * f.shaft))
        num += h * (KNUCKLE[f.name] - 1.0) * w
        den += w
    return num / np.maximum(1.0, den)


def knuckles(parts: dict, pos: dict, fingers: list, dors: np.ndarray) -> None:
    """Move 3 (D9, D96): each vertex lifts along the dorsal axis by `lift_field`, so the four
    heads stand out of the back of the hand. Skin within SKIRT of the finger tube takes the lift
    of the nearest tube point, so the finger-root skirt moves together with the tube."""
    tube = pos["fingers"]
    bvh = BVHTree.FromPolygons([tuple(v) for v in tube], [tuple(t) for t in parts["fingers"].tri])
    for key in parts:
        p = pos[key]
        lift = lift_field(p, fingers, dors)
        if key == "skin":
            near = [bvh.find_nearest(tuple(v)) for v in p]
            loc = np.array([n[0] if n[0] is not None else v for n, v in zip(near, p)])
            dist = np.array([n[3] if n[3] is not None else np.inf for n in near])
            # Within SKIRT the tube's lift, blending over the next 3 mm to the skin's own.
            tube_lift = lift_field(loc, fingers, dors)
            blend = smooth((dist - SKIRT) / 0.003)
            lift = tube_lift * (1.0 - blend) + lift * blend
        pos[key] = p + np.outer(lift, dors)


def knots(parts: dict, pos: dict, fingers: list, dors: np.ndarray) -> None:
    """Move 4 (D28, D32): the ring radius grows by g a d s at each joint, dorsal and stronger on
    the convex side of the kink, so the knots are uneven (art-arms: never a grid)."""
    for key, part in parts.items():
        for f in fingers:
            idx = np.nonzero(part.wt(*f.names) >= 0.5)[0]
            v = pos[key][idx]
            p = (v - f.head[0]) @ f.u
            centre = f.head[0] + np.outer(p, f.u) + np.outer(f.z(v), f.latf)
            rv = v - centre
            rv -= np.outer(rv @ f.u, f.u)
            r = np.maximum(np.linalg.norm(rv, axis=1), 1e-9)
            d = smooth(rv @ dors / (0.5 * r))
            grow = np.zeros(len(idx))
            for joint, g, conv in f.joints:
                a = 1.0 - smooth(np.abs(p - joint) / (0.5 * f.shaft))
                s = 0.75 + 0.25 * np.clip(rv @ (conv * f.latf) / r, -1.0, 1.0)
                grow += g * a * d * s
            pos[key][idx] = centre + rv * (1.0 + grow)[:, None]


def folds(parts: dict, pos: dict, fingers: list, dors: np.ndarray) -> None:
    """Move 5: Laplacian smoothing (factor 0.5, two passes) of the palm-half ring vertices within
    0.3 shaft of each knot, so the swelling does not pinch the palm side."""
    for key, part in parts.items():
        t = part.tri
        e = np.concatenate([t[:, [0, 1]], t[:, [1, 2]], t[:, [2, 0]]])
        e = np.concatenate([e, e[:, ::-1]])
        cnt = np.maximum(np.bincount(e[:, 0], minlength=len(part.co)), 1)
        sel = np.zeros(len(part.co), dtype=bool)
        for f in fingers:
            p = (pos[key] - f.head[0]) @ f.u
            rv = pos[key] - f.head[0] - np.outer(p, f.u) - np.outer(f.z(pos[key]), f.latf)
            own = part.wt(*f.names) >= 0.5
            for joint, _g, _c in f.joints:
                sel |= own & (np.abs(p - joint) <= 0.3 * f.shaft) & (rv @ dors < 0.0)
        for _ in range(2):
            avg = np.stack([np.bincount(e[:, 0], pos[key][e[:, 1], k], len(part.co))
                            for k in range(3)], axis=1) / cnt[:, None]
            pos[key][sel] += 0.5 * (avg[sel] - pos[key][sel])


def rotate(co: np.ndarray, w: np.ndarray, pivot: np.ndarray, axis: np.ndarray,
           deg: float, toward: np.ndarray, tip: np.ndarray) -> np.ndarray:
    """Rotate `co` about `axis` through `pivot` by deg x w per vertex, in the sense that turns
    the finger direction `tip` toward `toward`."""
    sgn = 1.0 if float(np.cross(axis, tip) @ toward) > 0 else -1.0
    ang = np.radians(deg) * w * sgn
    r = co - pivot
    c, s = np.cos(ang)[:, None], np.sin(ang)[:, None]
    rot = r * c + np.cross(axis, r) * s + axis * (r @ axis)[:, None] * (1.0 - c)
    return pivot + rot


def wreck(parts: dict, pos: dict, fr: HandFrame, fingers: list) -> None:
    """Move 2 (left hand only): the last joint of the index bent 30 degrees toward the thumb
    about the dorsal axis, of the ring 40 degrees palmward about the lateral axis."""
    lat, dors = np.array(fr.lat), np.array(fr.dors)
    for f in fingers:
        if f.name not in ("index", "ring"):
            continue
        z3 = f.sign * float(f.z_raw(np.array([f.pc]))[0])
        pivot = f.head[2] + f.latf * z3
        if f.name == "index":
            axis, deg, toward = dors, WRECK_INDEX_DEG, lat
        else:
            axis, deg, toward = lat, WRECK_RING_DEG, -dors
        for key, part in parts.items():
            pos[key] = rotate(pos[key], np.clip(part.wt(f.names[2]), 0.0, 1.0), pivot, axis, deg,
                              toward, f.u)


def main(args) -> None:
    S.prepare("fingers")
    lines = []
    for side in "LR":
        fr = HandFrame(side)
        parts = {k: S.Part("%s_%s" % (side, k)) for k in ("skin", "fingers", "webs")}
        for p in parts.values():
            assert p.ob.matrix_world.is_identity
        fingers = [Finger(fr, n, parts) for n in NAMES]
        if side == "L":
            for f in fingers:
                f.land = f.name not in ("index", "ring")
        dors = np.array(fr.dors)
        pos = zigzag(parts, fr, fingers)
        knuckles(parts, pos, fingers, dors)
        knots(parts, pos, fingers, dors)
        folds(parts, pos, fingers, dors)
        if side == "L":
            wreck(parts, pos, fr, fingers)
        for key, part in parts.items():
            d = part.grouped(pos[key] - part.co)
            n = part.write(part.co + d)
            tw = part.wt(*["DEF-thumb.0%d.%s" % (i, side) for i in (1, 2, 3)]) > 0.5
            lines.append("%s_%s moved %d, max |move| %.2f mm, thumb-weighted max %.2f mm" % (
                side, key, n, 1000 * float(np.linalg.norm(d, axis=1).max()),
                1000 * float(np.linalg.norm(d[tw], axis=1).max()) if tw.any() else 0.0))
    print("\n".join("FINGERS " + ln for ln in lines))
    S.finish()
