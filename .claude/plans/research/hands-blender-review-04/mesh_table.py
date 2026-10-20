"""Offline VeinMesh: loads `arms.py veindump` tables, answers gates.py's mesh interface.

`py -3 mesh_table.py <dir>` runs the committed sets.py through gates.check with the mesh
table per hand (no Blender) and prints FAILS / BLOCKING / per-gate counts like paths.txt,
then the max chart difference over the dump's 20 Blender sample points.
"""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gates import blocking, check  # noqa: E402
from sets import apply, side_L, side_R  # noqa: E402

VERB = {"R": 11 + 9 + 4 + 3 + 10 + 4 + 5 + 5, "L": 8 + 7 + 6 + 7 + 4}


class MeshTable:
    """The gates.py mesh interface over the dumped tables of both hands."""

    def __init__(self, path: str):
        self.d = {}
        for side in "RL":
            with open(os.path.join(path, "mesh_%s.json" % side)) as fh:
                j = json.load(fh)
            t = {k: np.array(j[k]) for k in ("ids", "s", "lat", "ch", "wmax")}
            t["span"], t["wrap"], t["samples"] = j["span"], j["wrap"], j["samples"]
            for k in ("fw", "tw", "edges", "fingers", "webs"):  # absent in old dumps
                t[k] = np.array(j[k]) if k in j else None
            t["dxy"] = np.stack([t["s"][t["ids"]] * t["span"], t["lat"][t["ids"]]], axis=1)
            t["axy"] = np.stack([t["s"] * t["span"], t["lat"]], axis=1)
            self.d[side] = t

    def chart(self, side: str, p) -> tuple:
        t = self.d[side]
        q = np.array([p[0] * t["span"], p[1]])
        dist = np.hypot(*(t["dxy"] - q).T)
        near = np.argsort(dist, kind="stable")[:4]
        wts = 1.0 / (dist[near] + 1e-9)
        ch = t["ch"][t["ids"][near]]
        w = t["wrap"]
        vs = ch[:, 1] - w * np.round((ch[:, 1] - ch[0, 1]) / w)  # unwrap beside the seam
        tot = wts.sum()
        return (float((wts * ch[:, 0]).sum() / tot), float((wts * vs).sum() / tot))

    def weight(self, side: str, p) -> float:
        t = self.d[side]
        q = np.array([p[0] * t["span"], p[1]])
        return float(t["wmax"][int(np.argmin(np.hypot(*(t["axy"] - q).T)))])

    def cover(self, side: str, chart_pts, r: float) -> int:
        t = self.d[side]
        cxy, w = t["ch"][:, :2], t["wrap"]
        hit = np.zeros(len(cxy), dtype=bool)
        for c in chart_pts:
            dv = cxy[:, 1] - c[1]
            dv -= w * np.round(dv / w)
            hit |= np.hypot(cxy[:, 0] - c[0], dv) <= 2.26 * r
        return int(hit.sum())


def main(path: str) -> None:
    mesh = MeshTable(path)
    for side, fn in (("R", side_R), ("L", side_L)):
        P = apply(side, fn())
        fails, _ = check(side, P, VERB[side], mesh=mesh)
        print("== %s FAILS %d BLOCKING %d" % (side, len(fails), len(blocking(fails))))
        tally = {}
        for f in fails:
            tally[f.split()[0]] = tally.get(f.split()[0], 0) + 1
        print("TALLY %s %s" % (side, " ".join("%s %d" % kv for kv in sorted(tally.items()))))
        diff = max(max(abs(a - b) for a, b in zip(mesh.chart(side, s["p"]), s["chart"]))
                   for s in mesh.d[side]["samples"])
        print("SAMPLE %s max chart diff %.3g over %d points"
              % (side, diff, len(mesh.d[side]["samples"])))


if __name__ == "__main__":
    main(sys.argv[1])
