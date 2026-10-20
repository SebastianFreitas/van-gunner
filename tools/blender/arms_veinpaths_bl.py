"""`arms.py veinpaths <dir>`: the traced vein paths on the real mesh chart, with approval sheets.

Runs as `blender -b --factory-startup arms.blend --python arms_veinpaths_bl.py -- <dir>`.
Per hand renders the current _next set (the rejected one), dumps the mesh tables, traces the
owner's photo (arms_veintrace) with its gates, writes <dir>/paths.txt and the
vein_set_<side>_next.tres (arms_veinsplice), renders the traced set and composes
<dir>/sheet_<side>_back.png. Never saves arms.blend or the live vein sets.
"""
import os

import arms_veindump_bl
import arms_veintrace as T
import bl_result
from arms_veinmesh import VeinMesh
from arms_veinpaint_bl import SHEET_S, _read, render_set, sheet
from arms_veinsplice import PALM, splice_write


def main(args) -> None:
    out = args[0]
    os.makedirs(out, exist_ok=True)
    arms_veindump_bl.main([out])
    table = T.load_mesh(out)
    lines = []
    for side in "RL":
        mesh = VeinMesh(side)
        rejected = os.path.join(out, "rejected_%s_back.png" % side)
        render_set(side, mesh, _read(side, "_next"), rejected, SHEET_S)
        res, fails, pk = T.run(side, table)
        lines.append("== " + side)
        lines += _report_lines(T, res, fails, pk)
        lines += splice_write(side, res["paths"], lambda p: mesh.chart(side, p))
        traced = os.path.join(out, "traced_%s_back.png" % side)
        render_set(side, mesh, _read(side, "_next"), traced, SHEET_S)
        lines.append("PNG " + sheet(side, out, traced, rejected))
    with open(os.path.join(out, "paths.txt"), "w") as fh:
        fh.write("\n".join(lines) + "\n")
    print("\n".join(lines))


def _report_lines(T, res: dict, fails: dict, pk: int) -> list:
    """The lines arms_veintrace.report prints, captured."""
    import contextlib
    import io
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        T.report(res, fails, pk)
    return buf.getvalue().splitlines()


if __name__ == "__main__":
    main(bl_result.args())
    bl_result.write("veinpaths")
