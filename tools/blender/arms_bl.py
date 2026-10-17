"""Blender side of tools/blender/arms.py: import, build and preview of the arms glb.

Run as `blender -b --factory-startup [arms.blend] --python arms_bl.py -- <mode> <args>`.
"""
import os
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
BLEND = os.path.join(HERE, "arms.blend")
GLB_OUT = os.path.abspath(os.path.join(HERE, "..", "..", "assets", "models", "arms", "arms.glb"))
MESHES = ("ArmL", "ArmR")
PARTS = tuple(s + "_" + p for s in "LR" for p in ("skin", "fingers", "webs"))


def _export(path: str = GLB_OUT) -> None:
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    keep = [bpy.data.objects["rig"]] + [bpy.data.objects[n] for n in PARTS]
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
    arms[0].name = "rig"
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


def _archive(names: list) -> None:
    """Move objects to the hidden `archive_` collection (removed art is archived, never deleted)."""
    arch = bpy.data.collections.get("archive_")
    if arch is None:
        arch = bpy.data.collections.new("archive_")
        bpy.context.scene.collection.children.link(arch)
    for n in names:
        ob = bpy.data.objects.get(n)
        if ob is None:
            continue
        for c in list(ob.users_collection):
            c.objects.unlink(ob)
        arch.objects.link(ob)
    old = bpy.data.collections.get("cc0")
    if old is not None and not old.objects:
        bpy.data.collections.remove(old)
    arch.hide_render = True
    arch.hide_viewport = True
    bpy.context.view_layer.layer_collection.children["archive_"].exclude = True


def do_import_baked(glb: str, force: bool) -> None:
    """Replace the source meshes with the baked parts, skinned to the existing rig."""
    if bpy.data.objects.get(PARTS[0]) and not force:
        raise SystemExit("Error: baked parts already in arms.blend; pass --force")
    for n in PARTS:
        ob = bpy.data.objects.get(n)
        if ob:
            me = ob.data
            bpy.data.objects.remove(ob)
            bpy.data.meshes.remove(me)
    before = set(bpy.data.objects.keys())
    bpy.ops.import_scene.gltf(filepath=glb)
    new = [o for o in bpy.data.objects if o.name not in before]
    rig = bpy.data.objects["rig"]
    bones = {b.name.replace(".", "_"): b.name for b in rig.data.bones}
    for o in new:
        if o.type == "MESH" and o.name in PARTS:
            for g in o.vertex_groups:
                # Blender made the second skeleton's names unique with a trailing "2".
                key = g.name[:-1] if g.name.endswith("2") else g.name
                g.name = bones[key]
            for m in o.modifiers:
                if m.type == "ARMATURE":
                    m.object = rig
            o.parent = rig
            o.matrix_parent_inverse = Matrix.Identity(4)
    for o in new:
        if o.type != "MESH" or o.name not in PARTS:
            bpy.data.objects.remove(o)
    missing = [n for n in PARTS if n not in bpy.data.objects]
    assert not missing, "baked glb lacks parts " + str(missing)
    _archive(list(MESHES) + ["cc0_" + n for n in MESHES])
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_mainfile(compress=True)
    print("SAVED", BLEND, os.path.getsize(BLEND))


def do_build() -> None:
    # arms_edit_bl.apply is not run: its steps are for the raw archived meshes (all off anyway).
    bpy.context.preferences.filepaths.save_version = 0  # no arms.blend1 backup
    bpy.ops.wm.save_mainfile(compress=True)
    print("SAVED", BLEND, os.path.getsize(BLEND))
    _export()


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
    rig = bpy.data.objects["rig"]
    rw = rig.matrix_world

    def head(b):
        return rw @ rig.data.bones[b].head_local
    H = head("DEF-hand.R")
    M = head("DEF-f_middle.01.R")
    span = (M - H).length
    axis = (M - H).normalized()
    up = Vector((0, 0, 1))
    dors = (up - axis * up.dot(axis)).normalized()
    lat = head("DEF-f_index.01.R") - head("DEF-f_pinky.01.R")
    lat = (lat - axis * lat.dot(axis)).normalized()
    ob = bpy.data.objects["R_skin"]
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
        json.dump({"part": "R_skin", "ids": ids, "offset": [off.x, off.z, -off.y]}, f)
    print("PROVE", len(ids), "vertices moved", tuple(off), "->", out_glb)


def do_preview(out: str) -> None:
    os.makedirs(out, exist_ok=True)
    sc = bpy.context.scene
    rig = bpy.data.objects["rig"]
    bpy.data.collections["archive_"].hide_render = False
    bpy.context.view_layer.layer_collection.children["archive_"].exclude = False
    rw = rig.matrix_world

    def head(b):
        return rw @ rig.data.bones[b].head_local
    H = head("DEF-hand.R")
    M = head("DEF-f_middle.01.R")
    span = (M - H).length
    axis = (M - H).normalized()
    up = Vector((0, 0, 1))
    dors = (up - axis * up.dot(axis)).normalized()
    lat = head("DEF-f_index.01.R") - head("DEF-f_pinky.01.R")
    lat = (lat - axis * lat.dot(axis)).normalized()
    cc0 = bpy.data.objects["cc0_ArmR"]
    new = [bpy.data.objects[n] for n in PARTS if n.startswith("R_")]
    # Frame on the cc0 right hand: vertices past the wrist along the hand axis.
    pts = [cc0.matrix_world @ v.co for v in cc0.data.vertices]
    hand = [p for p in pts if (p - H).dot(axis) > -0.02 * span]
    lo = min(p.dot(lat) for p in hand)
    hi = max(p.dot(lat) for p in hand)
    centre = H + axis * span * 0.55
    scale = max(span * 2.2, (hi - lo) * 1.4)
    for n in ("cc0_ArmL", "ArmL", "ArmR") + tuple(q for q in PARTS if q.startswith("L_")):
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
    args = sys.argv[sys.argv.index("--") + 1:]
    mode = args[0]
    if mode == "import":
        do_import(args[1])
    elif mode == "import-baked":
        do_import_baked(args[1], "force" in args[2:])
    elif mode == "build":
        do_build()
    elif mode == "prove":
        do_prove(args[1], args[2])
    elif mode == "preview":
        do_preview(args[1])
    else:
        raise SystemExit("unknown mode " + mode)


main()
