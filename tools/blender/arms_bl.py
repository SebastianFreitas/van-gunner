"""Blender side of tools/blender/arms.py: import, build and preview of the arms glb.

Run as `blender -b --factory-startup [arms.blend] --python arms_bl.py -- <mode> <args>`.
"""
import os
import sys

import bpy
from mathutils import Matrix, Vector

from arm_names import BLEND, GLB_OUT, MESHES, PARTS, VG_HAND, VG_INDEX1, VG_MIDDLE1, VG_PINKY1, SKIN, RIG
import bl_result  # noqa: E402
from arms_frame_bl import hand_frame  # noqa: E402


def _export(path: str = GLB_OUT) -> None:
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    keep = [bpy.data.objects[RIG]] + [bpy.data.objects[n] for n in PARTS]
    for o in keep:
        o.select_set(True)
    bpy.context.view_layer.objects.active = keep[0]
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True,
        export_materials="NONE", export_animations=False, export_def_bones=True,
        export_yup=True, export_apply=False, export_extras=False,
        export_texcoords=True, export_normals=True, export_skins=True, export_morph=False,
        export_attributes=True)
    print("EXPORTED", path, os.path.getsize(path))


def do_import(glb: str) -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=glb)
    ico = bpy.data.objects.get("Icosphere")
    if ico:
        bpy.data.objects.remove(ico)
    arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    assert len(arms) == 1, "expected one armature"
    arms[0].name = RIG
    for n in MESHES:
        assert n in bpy.data.objects, "missing mesh " + n
    col = bpy.data.collections.new("cc0")
    bpy.context.scene.collection.children.link(col)
    for n in MESHES:
        src = bpy.data.objects[n]
        cp = src.copy()
        cp.data = src.data.copy()
        cp.name = "cc0_" + n
        cp.data.name = "cc0_" + n
        col.objects.link(cp)
    bpy.context.view_layer.layer_collection.children["cc0"].exclude = True
    bpy.ops.wm.save_as_mainfile(filepath=BLEND, compress=True)
    print("SAVED", BLEND, os.path.getsize(BLEND))


def do_build(glb: str = GLB_OUT) -> None:
    bl_result.check_names()
    # arms_edit_bl.apply is not run: its steps are for the raw archived meshes (all off anyway).
    bpy.context.preferences.filepaths.save_version = 0  # no arms.blend1 backup
    bpy.ops.wm.save_mainfile(compress=True)
    print("SAVED", bpy.data.filepath, os.path.getsize(bpy.data.filepath))
    _export(glb)


def _stored_ids(ob) -> dict:
    """{vertex index: id} from the vertex id channel the export carries as CUSTOM2.w.

    It is the last UV layer's v (the glb writes 1 - v); a vertex whose loops disagree or
    whose value is not a whole id >= 0 (added since the ids were stamped) is left out.
    """
    me = ob.data
    uv = me.uv_layers[len(me.uv_layers) - 1]
    out = {}
    bad = set()
    for lp in me.loops:
        x = 1.0 - uv.data[lp.index].uv[1]
        i = lp.vertex_index
        if abs(x - round(x)) > 1e-3 or x < -0.5 or out.get(i, round(x)) != round(x):
            bad.add(i)
        out[i] = round(x)
    return {i: v for i, v in out.items() if i not in bad}


def do_prove(out_glb: str, out_json: str) -> None:
    """Move R_skin's back-of-hand slab 4 mm outward in memory and export it to a scratch glb.

    arms.blend is not saved and arms.glb not written. The json lists the moved vertices'
    stored CUSTOM2.w ids (not Blender indices) and the offset in glb axes.
    """
    import json
    bl_result.check_names()
    fr = hand_frame("R")
    H, span, axis, dors, lat = fr.H, fr.span, fr.axis, fr.dors, fr.lat
    ob = bpy.data.objects["R" + SKIN]
    pts = [ob.matrix_world @ v.co for v in ob.data.vertices]
    # Back of the hand: the slab 0.3..0.5 of the way to the middle knuckle, on the dorsal side.
    idx = [i for i, p in enumerate(pts)
           if 0.3 <= (p - H).dot(axis) / span <= 0.5 and (p - H).dot(dors) > 0.0]
    assert len(idx) >= 50, "slab too small: %d" % len(idx)
    stored = _stored_ids(ob)
    ids = []
    for i in idx:
        if i not in stored:
            sys.exit("PROVE ERROR: R_skin vertex %d has no stored CUSTOM2.w id" % i)
        ids.append(stored[i])
    if len(set(stored[i] for i in idx)) != len(idx):
        sys.exit("PROVE ERROR: R_skin moved vertices share a stored CUSTOM2.w id")
    off = -lat * 0.004
    for i in idx:
        ob.data.vertices[i].co += ob.matrix_world.inverted().to_3x3() @ off
    ob.data.update()
    _export(out_glb)
    with open(out_json, "w") as f:
        json.dump({"part": "R" + SKIN, "ids": ids, "offset": [off.x, off.z, -off.y]}, f)
    print("PROVE", len(ids), "vertices moved", tuple(off), "->", out_glb)


def do_preview(out: str) -> None:
    os.makedirs(out, exist_ok=True)
    sc = bpy.context.scene
    rig = bpy.data.objects[RIG]
    bpy.data.collections["archive_"].hide_render = False
    bpy.context.view_layer.layer_collection.children["archive_"].exclude = False
    rw = rig.matrix_world

    def head(b):
        return rw @ rig.data.bones[b].head_local
    H = head(VG_HAND + ".R")
    M = head(VG_MIDDLE1 + ".R")
    span = (M - H).length
    axis = (M - H).normalized()
    up = Vector((0, 0, 1))
    dors = (up - axis * up.dot(axis)).normalized()
    lat = head(VG_INDEX1 + ".R") - head(VG_PINKY1 + ".R")
    lat = (lat - axis * lat.dot(axis)).normalized()
    cc0 = bpy.data.objects["cc0_" + MESHES[1]]
    new = [bpy.data.objects[n] for n in PARTS if n.startswith("R_")]
    # Frame on the cc0 right hand: vertices past the wrist along the hand axis.
    pts = [cc0.matrix_world @ v.co for v in cc0.data.vertices]
    hand = [p for p in pts if (p - H).dot(axis) > -0.02 * span]
    lo = min(p.dot(lat) for p in hand)
    hi = max(p.dot(lat) for p in hand)
    centre = H + axis * span * 0.55
    scale = max(span * 2.2, (hi - lo) * 1.4)
    for n in ("cc0_" + MESHES[0],) + MESHES + tuple(q for q in PARTS if q.startswith("L_")):
        bpy.data.objects[n].hide_render = True
    rig.hide_render = True
    cc0.hide_viewport = False
    for ob, col in [(cc0, (0.70, 0.62, 0.50, 1))] + [(o, (0.55, 0.62, 0.50, 1)) for o in new]:
        ob.color = col
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading
    sh.light = "STUDIO"
    sh.color_type = "OBJECT"
    sh.show_object_outline = True
    cam_d = bpy.data.cameras.new("c")
    cam_d.type = "ORTHO"
    cam = bpy.data.objects.new("cam", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam
    sc.world = sc.world or bpy.data.worlds.new("w")
    # Both meshes are skinned to the same rig and overlap, so render each alone and stitch
    # the two images side by side (cc0 left, the baked R parts right).
    for name, view, upv in (("back", -dors, axis), ("palm", dors, axis), ("side", -lat, axis)):
        shots = []
        for which in (cc0, new):
            cc0.hide_render = which is not cc0
            for o in new:
                o.hide_render = which is cc0
            d = view.normalized()
            z = -d
            x = upv.cross(z).normalized()
            y = z.cross(x)
            rot = Matrix((x, y, z)).transposed().to_4x4()
            cam.matrix_world = Matrix.Translation(centre + d * -2.0) @ rot
            cam_d.ortho_scale = scale
            cam_d.clip_start = 0.01
            cam_d.clip_end = 10
            sc.render.resolution_x = 400
            sc.render.resolution_y = 400
            fp = os.path.join(out, "_%s_%d.png" % (name, len(shots)))
            sc.render.filepath = fp
            bpy.ops.render.render(write_still=True)
            shots.append(fp)
        a = bpy.data.images.load(shots[0])
        b = bpy.data.images.load(shots[1])
        w, h = a.size
        ap, bp = list(a.pixels), list(b.pixels)
        px = []
        for r in range(h):
            px += ap[r * w * 4:(r + 1) * w * 4] + bp[r * w * 4:(r + 1) * w * 4]
        im = bpy.data.images.new("m_" + name, w * 2, h)
        im.pixels = px
        im.filepath_raw = os.path.join(out, name + ".png")
        im.file_format = "PNG"
        im.save()
        for fp in shots:
            os.remove(fp)
    print("PREVIEW", out)


def main() -> None:
    args = bl_result.args()
    mode = args[0]
    if mode == "import":
        do_import(args[1])
    elif mode == "build":
        do_build(*args[1:2])
    elif mode == "prove":
        do_prove(args[1], args[2])
    elif mode == "preview":
        do_preview(args[1])
    else:
        raise SystemExit("unknown mode " + mode)
    bl_result.write(mode, blend_bytes=os.path.getsize(BLEND) if os.path.exists(BLEND) else 0)


if __name__ == "__main__":
    main()
