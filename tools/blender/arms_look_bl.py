"""Blender side of `arms.py look <dir> [--before <step>]`: look renders of both hands.

Runs as `blender -b --factory-startup arms.blend --python arms_look_bl.py -- <dir> [<step>]`.
Never saves the blend. Writes <dir>/<hand>_<view>.png (back, palm, side per hand),
<hand>_tip_<finger>.png and <hand>_knuckle_<finger>.png (4x close-ups from the back) at
2048x1024 and <dir>/look.txt. With a step the left half shows the `archive_` copies
`<step>_<part>`, the right half the live parts; without one the live parts are on the
right and the left half is empty background.
"""
import os
import sys

import bpy
import numpy as np

from arm_names import PARTS, FINGERS, VG_FING_ROOT, VG_FING_TIP, RIG
import bl_result  # noqa: E402
from arms_frame_bl import hand_frame  # noqa: E402
from arms_hunt_bl import setup_render, shoot  # noqa: E402

HALF = 1024
S_LO, S_HI = -0.2, 2.2
GREY = (0.62, 0.62, 0.62, 1)


def prepare(sc, step):
    """Rest pose, one grey solid colour with cavity; returns the archive objects (or None)."""
    bpy.data.objects[RIG].data.pose_position = "REST"
    arch = bpy.data.collections["archive_"]
    olds = {}
    if step:
        for ob in arch.objects:
            olds[ob.name] = ob
        olds = {p: olds.get(step + "_" + p) for p in PARTS}
        if not any(olds.values()):
            sys.exit("Error: no archive_ %s_*" % step)
    arch.hide_render = False
    bpy.context.view_layer.layer_collection.children["archive_"].exclude = False
    for ob in arch.objects:
        ob.hide_render = True
    sc.render.resolution_x = HALF
    sc.render.resolution_y = HALF
    sh = sc.display.shading
    sh.show_shadows = False
    sh.show_cavity = True
    sh.cavity_type = "BOTH"
    sh.cavity_ridge_factor = 1.0
    sh.cavity_valley_factor = 1.0
    sh.curvature_ridge_factor = 0.0
    sh.curvature_valley_factor = 0.0
    for ob in list(olds.values()) + [bpy.data.objects[p] for p in PARTS]:
        if ob:
            ob.color = GREY
    return olds


def show(live, olds):
    for p in PARTS:
        bpy.data.objects[p].hide_render = not live
        if olds.get(p):
            olds[p].hide_render = live


def pixels(path):
    im = bpy.data.images.load(path)
    a = np.empty(len(im.pixels), dtype=np.float32)
    im.pixels.foreach_get(a)
    bpy.data.images.remove(im)
    return a.reshape(HALF, HALF, 4)


def take(sc, cam, cam_d, path, olds, target, view, scale, up):
    """Left half the archive copies, right half the live parts, into one 2048x1024 png."""
    tmp = path[:-4] + "_tmp.png"
    halves = []
    for live in (False, True):
        show(live, olds)
        if not live and not olds:
            halves.append(None)
            continue
        shoot(sc, cam, cam_d, tmp, target, view, scale, up)
        halves.append(pixels(tmp))
    os.remove(tmp)
    if halves[0] is None:
        halves[0] = np.empty_like(halves[1])
        halves[0][:] = halves[1][0, 0]
    im = bpy.data.images.new("look", HALF * 2, HALF)
    im.pixels.foreach_set(np.concatenate(halves, axis=1).ravel())
    im.filepath_raw = path
    im.file_format = "PNG"
    im.save()
    bpy.data.images.remove(im)


def main(args) -> None:
    out = args[0]
    os.makedirs(out, exist_ok=True)
    sc, cam, cam_d = setup_render()
    olds = prepare(sc, args[1] if len(args) > 1 else None)
    lines = []
    for side in "LR":
        fr = hand_frame(side)
        centre = fr.point((S_LO + S_HI) / 2)
        scale = (S_HI - S_LO) * fr.span * 1.04
        views = (("back", -fr.dors), ("palm", fr.dors), ("side", -fr.lat))
        for name, view in views:
            fn = "%s_%s.png" % (side, name)
            take(sc, cam, cam_d, os.path.join(out, fn), olds, centre, view, scale, fr.axis)
            lines.append("%s %s view, s %.1f..%.1f" % (fn, name, S_LO, S_HI))
        for f in FINGERS:
            rig = bpy.data.objects[RIG]
            bone = rig.data.bones[(VG_FING_TIP + ".%s") % (f, side)]
            pts = (("tip", rig.matrix_world @ bone.tail_local),
                   ("knuckle", fr.head(VG_FING_ROOT % f)))
            for kind, p in pts:
                fn = "%s_%s_%s.png" % (side, kind, f)
                take(sc, cam, cam_d, os.path.join(out, fn), olds, p, -fr.dors,
                     (S_HI - S_LO) * fr.span * 1.04 / 4, fr.axis)
                lines.append("%s %s of %s, 4x, from the back" % (fn, kind, f))
    with open(os.path.join(out, "look.txt"), "w") as fh:
        fh.write("\n".join(lines) + "\n")
    print("LOOK", out, len(lines))
    bl_result.write("look", lines=len(lines))


if __name__ == "__main__":
    main(bl_result.args())
