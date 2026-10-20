"""Shared helper of the scripted arms steps: `arms.py step <name> [args]` runs `main` here.

Runs as `blender -b --factory-startup arms.blend --python arms_step_bl.py -- <name> [args]`
and calls `arms_<name>_bl.main(args)`. A step calls `prepare(name)` first: the first run copies
the six live parts (own mesh data) into the hidden `archive_` collection as `<name>_<part>`;
a re-run restores the live meshes from those copies, so numbers never compound. A step ends
with `finish()` (`arms_bl.do_build`: saves arms.blend, exports the live parts). Existing
vertices only; coincident vertices (1e-6 m) move as one group by their mean vector.
"""
import importlib
import os
import sys

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
PARTS = tuple(s + "_" + p for s in "LR" for p in ("skin", "fingers", "webs"))


def prepare(name: str) -> bool:
    """Archive the live parts as `<name>_<part>` (first run) or restore them (re-run)."""
    arch = bpy.data.collections["archive_"]
    again = all(bpy.data.objects.get(name + "_" + p) is not None for p in PARTS)
    for p in PARTS:
        ob = bpy.data.objects[p]
        if again:
            old = ob.data
            new = bpy.data.objects[name + "_" + p].data.copy()
            ob.data = new
            bpy.data.meshes.remove(old)
            new.name = p
        else:
            cp = ob.copy()
            cp.data = ob.data.copy()
            cp.name = name + "_" + p
            arch.objects.link(cp)
    return again


class Part:
    """A live part as numpy arrays: positions `co`, triangles `tri`, coincident-vertex groups."""

    def __init__(self, name: str):
        self.ob = bpy.data.objects[name]
        me = self.ob.data
        n = len(me.vertices)
        self.co = np.empty(n * 3)
        me.vertices.foreach_get("co", self.co)
        self.co = self.co.reshape(n, 3)
        me.calc_loop_triangles()
        self.tri = np.empty(len(me.loop_triangles) * 3, dtype=np.int64)
        me.loop_triangles.foreach_get("vertices", self.tri)
        self.tri = self.tri.reshape(-1, 3)
        names = {g.index: g.name for g in self.ob.vertex_groups}
        self.w = {}
        for v in me.vertices:
            for g in v.groups:
                self.w.setdefault(names[g.group], np.zeros(n))[v.index] = g.weight
        key = np.round(self.co * 1e6).astype(np.int64)
        self.gid = np.unique(key, axis=0, return_inverse=True)[1].reshape(-1)

    def wt(self, *names) -> np.ndarray:
        return sum((self.w.get(nm, 0) for nm in names), np.zeros(len(self.co)))

    def area(self, co=None) -> np.ndarray:
        """Third of the summed area of each vertex's triangles."""
        co = self.co if co is None else co
        t = self.tri
        a = 0.5 * np.linalg.norm(np.cross(co[t[:, 1]] - co[t[:, 0]], co[t[:, 2]] - co[t[:, 0]]),
                                 axis=1) / 3.0
        return np.bincount(t.ravel(), np.repeat(a, 3), len(co))

    def grouped(self, d: np.ndarray) -> np.ndarray:
        """Displacements `d` with each coincident group set to its mean."""
        cnt = np.bincount(self.gid)
        m = np.stack([np.bincount(self.gid, d[:, k]) / cnt for k in range(3)], axis=1)
        return m[self.gid]

    def write(self, new: np.ndarray) -> int:
        """Set positions to `new` (already grouped); renormalise the moved vertices and their
        one ring (area-weighted); returns the number moved."""
        me = self.ob.data
        moved = np.linalg.norm(new - self.co, axis=1) > 0
        # Normals as they were before the move: the update below recomputes the corner normals.
        nl = len(me.loops)
        pre = np.empty(nl * 3)
        me.corner_normals.foreach_get("vector", pre)
        pre = pre.reshape(-1, 3)
        plv = np.empty(nl, dtype=np.int64)
        me.loops.foreach_get("vertex_index", plv)
        pre = np.stack([np.bincount(plv, pre[:, k], len(new)) for k in range(3)], 1)
        pre /= np.maximum(np.linalg.norm(pre, axis=1), 1e-12)[:, None]
        me.vertices.foreach_set("co", new.ravel())
        me.update()
        if not moved.any():
            return 0
        t = self.tri
        near = moved[t].any(axis=1)
        ring = np.zeros(len(new), dtype=bool)
        ring[t[near].ravel()] = True
        fn = np.cross(new[t[:, 1]] - new[t[:, 0]], new[t[:, 2]] - new[t[:, 0]])
        vn = np.stack([np.bincount(t.ravel(), np.repeat(fn[:, k], 3), len(new)) for k in range(3)], 1)
        cur = np.empty(nl * 3)
        me.corner_normals.foreach_get("vector", cur)
        cur = cur.reshape(-1, 3)
        lv = np.empty(nl, dtype=np.int64)
        me.loops.foreach_get("vertex_index", lv)
        # Coincident groups whose members shared one normal before (UV seams) get the group's
        # summed normal; groups that were hard edges keep one normal per vertex.
        gmin = np.stack([np.full(self.gid.max() + 1, 9.0) for _ in range(3)], 1)
        gmax = -gmin.copy()
        for k in range(3):
            np.minimum.at(gmin[:, k], self.gid, pre[:, k])
            np.maximum.at(gmax[:, k], self.gid, pre[:, k])
        smooth = (gmax - gmin).max(axis=1) < 1e-3
        smooth &= np.bincount(self.gid) > 1
        self.seam_moved = int(len(np.unique(self.gid[moved & smooth[self.gid]])))
        vs = np.stack([np.bincount(self.gid, vn[:, k]) for k in range(3)], 1)[self.gid]
        vn = np.where(smooth[self.gid][:, None], vs, vn)
        vn /= np.maximum(np.linalg.norm(vn, axis=1), 1e-12)[:, None]
        sel = ring[lv]
        cur[sel] = vn[lv[sel]]
        me.normals_split_custom_set(cur.tolist())
        self.co = new
        return int(moved.sum())


def finish() -> None:
    import arms_bl
    arms_bl.do_build()


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1:]
    importlib.import_module("arms_%s_bl" % args[0]).main(args[1:])


if __name__ == "__main__":
    main()
