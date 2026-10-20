"""`arms.py veindump <dir>`: dumps what VeinMesh uses to <dir>/mesh_R.json and mesh_L.json.

Runs as `blender -b --factory-startup arms.blend --python arms_veindump_bl.py -- <dir>`.
Research 04's mesh_table.py loads the dump offline (same chart/weight/cover answers as
arms_veinpaths_bl.VeinMesh), plus 20 sample points with Blender's chart answer as a proof.
Never saves arms.blend.
"""
import json
import os

import bpy
import numpy as np

from arms_veinmesh import WRAP, VeinMesh
import bl_result  # noqa: E402
from arms_frame_bl import hand_frame  # noqa: E402
from arms_veinsets import apply, side_L, side_R  # noqa: E402
from arm_names import SKIN, FINGERS_PART, WEBS


def part_sl(name: str, fr) -> list:
    """[s, lat] (s in span units, as the skin's s) per vertex of the evaluated part; [] if none."""
    ob = bpy.data.objects.get(name)
    if ob is None:
        return []
    ev = ob.evaluated_get(bpy.context.evaluated_depsgraph_get())
    n = len(ev.data.vertices)
    co = np.zeros(n * 3)
    ev.data.vertices.foreach_get("co", co)
    mw = np.array(ev.matrix_world)
    d = co.reshape(-1, 3) @ mw[:3, :3].T + mw[:3, 3] - np.array(fr.H)
    return np.stack([d @ np.array(fr.axis) / fr.span, d @ np.array(fr.lat)], axis=1).tolist()


def main(args) -> None:
    out = args[0]
    os.makedirs(out, exist_ok=True)
    for side, fn in (("R", side_R), ("L", side_L)):
        mesh = VeinMesh(side)
        fr = hand_frame(side)
        ev = bpy.data.objects[side + SKIN].evaluated_get(bpy.context.evaluated_depsgraph_get())
        P = apply(side, fn())
        pts = [p[:2] for q in P.values() for p in q["pts"]]
        pts = pts[::max(1, len(pts) // 20)][:20]
        samples = [{"p": list(p), "chart": list(mesh.chart(side, p))} for p in pts]
        d = {"side": side, "span": mesh.span, "wrap": WRAP, "ids": mesh.ids.tolist(),
             "s": mesh.s.tolist(), "lat": mesh.lat.tolist(), "ch": mesh.ch.tolist(),
             "wmax": mesh.wmax.tolist(), "samples": samples,
             "fw": mesh.fw[mesh.ids].tolist(), "tw": mesh.tw[mesh.ids].tolist(),
             # s * span and lat are in metres for every skin vertex, so edge lengths need no more
             "edges": [list(e.vertices) for e in ev.data.edges],
             "fingers": part_sl(side + FINGERS_PART, fr), "webs": part_sl(side + WEBS, fr)}
        with open(os.path.join(out, "mesh_%s.json" % side), "w") as fh:
            json.dump(d, fh)
        print("dumped", side, len(mesh.s), "verts", len(mesh.ids), "dorsal")


if __name__ == "__main__":
    main(bl_result.args())
    bl_result.write("veindump")
