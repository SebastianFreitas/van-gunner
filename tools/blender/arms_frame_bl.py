"""The per-hand frame shared by the arms Blender steps (prove, look, later edit steps).

Origin at the DEF-hand head, axis to DEF-f_middle.01, lat from the pinky to the index
knuckle, dorsal = world up less its axis component. `s` is along the axis in units of
the hand-to-middle-knuckle span (0 = wrist head, 1 = middle knuckle); lat and dorsal are
metres.
"""
import math

import bpy
from mathutils import Vector


class HandFrame:
    def __init__(self, side: str):
        rig = bpy.data.objects["rig"]
        rw = rig.matrix_world

        def head(b):
            return rw @ rig.data.bones[b + "." + side].head_local
        self.side = side
        self.head = head
        self.H = head("DEF-hand")
        M = head("DEF-f_middle.01")
        self.span = (M - self.H).length
        self.axis = (M - self.H).normalized()
        up = Vector((0, 0, 1))
        self.dors = (up - self.axis * up.dot(self.axis)).normalized()
        lat = head("DEF-f_index.01") - head("DEF-f_pinky.01")
        self.lat = (lat - self.axis * lat.dot(self.axis)).normalized()

    def s(self, p: Vector) -> float:
        return (p - self.H).dot(self.axis) / self.span

    def coords(self, p: Vector) -> tuple:
        """(s, lat, dorsal) of a world-space point."""
        d = p - self.H
        return (d.dot(self.axis) / self.span, d.dot(self.lat), d.dot(self.dors))

    def point(self, s: float, lat: float = 0.0, dorsal: float = 0.0) -> Vector:
        return self.H + self.axis * (s * self.span) + self.lat * lat + self.dors * dorsal


def hand_frame(side: str) -> HandFrame:
    return HandFrame(side)


class ShapeFrame(HandFrame):
    """The frame of Godot's `arms hands` shape rows (debug_arms_hands_rows.gd `shape()`).

    span = head to the four `.01` roots' centre along the axis; lat points from the index to
    the pinky root (the pinky side is +lat), not the other way as in `HandFrame`.
    """

    def __init__(self, side: str):
        super().__init__(side)
        names = ("index", "middle", "ring", "pinky")
        roots = [self.head("DEF-f_%s.01" % n) for n in names]
        self.roots = roots
        self.span = ((roots[0] + roots[1] + roots[2] + roots[3]) * 0.25 - self.H).dot(self.axis)
        self.lat = -self.lat


def shape_frame(side: str) -> ShapeFrame:
    return ShapeFrame(side)


def chart(ob) -> list:
    """Per vertex of mesh object `ob`: (x, v, mask) of its CUSTOM0 chart, as GDScript
    `ArmVeinSet.chart_of` reads it. c = (UVMap.002 u, 1 - v, UVMap.003 u, 1 - v), loop UVs
    averaged per vertex; x = c.x, v = 0.035 atan2(c.z, c.y), mask = c.w."""
    me = ob.data
    n = len(me.vertices)
    vi = [lp.vertex_index for lp in me.loops]
    cnt = [0] * n
    for i in vi:
        cnt[i] += 1

    def per_vertex(name: str) -> list:
        acc = [[0.0, 0.0] for _ in range(n)]
        for lp, uv in zip(vi, me.uv_layers[name].data):
            acc[lp][0] += uv.uv[0]
            acc[lp][1] += uv.uv[1]
        return [(a[0] / max(c, 1), a[1] / max(c, 1)) for a, c in zip(acc, cnt)]
    a, b = per_vertex("UVMap.002"), per_vertex("UVMap.003")
    out = []
    for i in range(n):
        c = (a[i][0], 1 - a[i][1], b[i][0], 1 - b[i][1])
        out.append((c[0], 0.035 * math.atan2(c[2], c[1]), c[3]))
    return out
