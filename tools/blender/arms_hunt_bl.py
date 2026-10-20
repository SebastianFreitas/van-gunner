"""Blender side of `arms.py hunt <glb> <dir>`: finds defect clusters on the exported hands.

Runs as `blender -b --factory-startup --python arms_hunt_bl.py -- <glb> <dir>`. Needs the
`<glb minus .glb>.bones.json` the `arms export` console command writes beside the glb.
Writes <dir>/hunt.txt (one line per cluster), <dir>/clusters.txt (the baked vertex ids of each
cluster, when the glb carries them in its second UV set), orbit_<side>_<k>.png and close-ups
<kind>_<object>_<n>_<a>.png for the 8 worst clusters of each kind.
"""
import json
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

from arm_names import VG_HAND, VG_MIDDLE1, SKIN, FINGERS_PART
import bl_result  # noqa: E402
from arms_huntmesh import MERGE, face_elems, find_coincident, id_tree, ring_info  # noqa: E402

SLIVER_ANGLE = 3.0
SLIVER_RATIO = 15.0
SPIKE_K = 0.6
CREASE_DEG = 75.0
CLOSEUPS = 8
RES = 800
KINDS = ["inside_out", "inside_out_all", "sliver", "spike", "crease", "hole",
         "hole_expected", "coincident"]


def clusters(n, keys_of):
    """Indices 0..n-1 grouped when they share a key."""
    parent = list(range(n))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i
    owner = {}
    for i in range(n):
        for k in keys_of(i):
            if k in owner:
                parent[find(i)] = find(owner[k])
            else:
                owner[k] = i
    groups = {}
    for i in range(n):
        groups.setdefault(find(i), []).append(i)
    return list(groups.values())


def convert(p):
    """Godot (y up) position to Blender (z up), as the glTF importer does."""
    return Vector((p[0], -p[2], p[1]))


class Frame:
    def __init__(self, heads):
        self.bones = {n: convert(p) for n, p in heads.items()}

    def slab(self, side, p):
        h = self.bones[VG_HAND + "." + side]
        m = self.bones[VG_MIDDLE1 + "." + side]
        span = (m - h).length
        return (p - h).dot((m - h).normalized()) / span

    def nearest(self, p):
        return min(self.bones, key=lambda n: (self.bones[n] - p).length_squared)


def analyse(ob, side, frame):
    """List of cluster dicts for one mesh object."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.transform(ob.matrix_world)
    out = []
    is_claw = "_claw_" in ob.name
    idt = id_tree(ob)

    def ids_of(verts):
        """Every raw vertex id within the merge distance of these vertices, so a merged
        vertex keeps each id it absorbed (the raw positions are in the tree, not the bmesh)."""
        if idt is None:
            return None
        found = set()
        for v in verts:
            for _, i, _ in idt[0].find_range(v.co, 2 * MERGE):
                found |= idt[1][i]
        return sorted(found)

    def add(kind, elems, groups, worst_of, bad_of, verts_of=None):
        """elems: (pos, normal, value); a group becomes one cluster at its worst element."""
        for g in groups:
            w = max(g, key=lambda i: bad_of(elems[i]))
            pos, nrm, _ = elems[w]
            r = max((elems[i][0] - pos).length for i in g)
            out.append(dict(kind=kind, obj=ob.name, side=side, pos=pos, normal=nrm, r=r,
                            count=len(g), worst=worst_of(elems[w], g, elems),
                            bad=bad_of(elems[w]) if kind != "coincident" else len(g),
                            ids=ids_of([v for i in g for v in verts_of(i)]) if verts_of else None))

    # coincident, on the raw mesh before duplicate vertices are merged
    flagged, mult = find_coincident(bm)
    if flagged:
        el = [(f.calc_center_median(), f.normal.copy(), m) for f, m in zip(flagged, mult)]
        keyed = [[(round(v.co.x / MERGE), round(v.co.y / MERGE), round(v.co.z / MERGE))
                  for v in f.verts] for f in flagged]
        add("coincident", el, clusters(len(el), lambda i: keyed[i]),
            lambda e, g, els: "faces%d" % e[2], lambda e: e[2],
            lambda i: flagged[i].verts)

    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=MERGE)
    bm.verts.ensure_lookup_table()
    bm.edges.ensure_lookup_table()
    bm.faces.ensure_lookup_table()
    bm.verts.index_update()
    bm.edges.index_update()
    bm.faces.index_update()
    bm.normal_update()
    if not bm.faces:
        bm.free()
        return out

    # inside_out
    ref = bm.copy()
    bmesh.ops.recalc_face_normals(ref, faces=ref.faces[:])
    ref.faces.ensure_lookup_table()
    flipped = [f for f in bm.faces if f.normal.dot(ref.faces[f.index].normal) < 0]
    ref.free()
    if len(flipped) * 2 > len(bm.faces):
        out.append(dict(kind="inside_out_all", obj=ob.name, side=side,
                        pos=flipped[0].calc_center_median(), normal=flipped[0].normal.copy(),
                        r=0.0, count=len(flipped),
                        worst="frac%.2f" % (len(flipped) / len(bm.faces)), bad=0.0))
    elif flipped:
        el = [(f.calc_center_median(), f.normal.copy(), f.calc_area()) for f in flipped]
        add("inside_out", el,
            clusters(len(el), lambda i: [v.index for v in flipped[i].verts]),
            lambda e, g, els: "area%.5f" % sum(els[i][2] for i in g), lambda e: e[2],
            lambda i: flipped[i].verts)

    # sliver
    sl = []
    for f in bm.faces:
        angs = []
        lens = []
        for lp in f.loops:
            a = lp.link_loop_next.vert.co - lp.vert.co
            b = lp.link_loop_prev.vert.co - lp.vert.co
            lens.append(a.length)
            angs.append(math.degrees(a.angle(b, 0.0)) if a.length > 0 and b.length > 0 else 0.0)
        ang = min(angs)
        ratio = max(lens) / min(lens) if min(lens) > 0 else 1e9
        if ang < SLIVER_ANGLE or ratio > SLIVER_RATIO:
            sl.append((f, ang, ratio))
    if sl:
        el = [(f.calc_center_median(), f.normal.copy(), (a, r)) for f, a, r in sl]
        add("sliver", el, clusters(len(sl), lambda i: [v.index for v in sl[i][0].verts]),
            lambda e, g, els: "ang%.2f/ratio%.1f" % (min(els[i][2][0] for i in g),
                                                       min(max(els[i][2][1] for i in g), 9999)),
            lambda e: max(SLIVER_ANGLE / (e[2][0] + 1e-3), e[2][1] / SLIVER_RATIO),
            lambda i: sl[i][0].verts)

    # spike
    sp = []
    for v in bm.verts:
        info = ring_info(v)
        if info and info[0] > SPIKE_K * info[1]:
            sp.append((v, info[0] / info[1], info[2]))
    if sp:
        el = [(v.co.copy(), n, ratio) for v, ratio, n in sp]
        add("spike", el, clusters(len(sp), lambda i: [e.index for e in sp[i][0].link_edges]),
            lambda e, g, els: "h%.2f" % max(els[i][2] for i in g), lambda e: e[2],
            lambda i: [sp[i][0]])

    # crease (skin objects, not claws)
    if not is_claw:
        cr = []
        for e in bm.edges:
            if len(e.link_faces) == 2:
                d = math.degrees(e.calc_face_angle(0.0))
                if d > CREASE_DEG:
                    cr.append((e, d))
        if cr:
            el = [((e.verts[0].co + e.verts[1].co) / 2, e.link_faces[0].normal.copy(), d)
                  for e, d in cr]
            add("crease", el, clusters(len(cr), lambda i: [v.index for v in cr[i][0].verts]),
                lambda e, g, els: "%.1fdeg" % max(els[i][2] for i in g), lambda e: e[2],
            lambda i: cr[i][0].verts)

    # holes: boundary loops
    be = [e for e in bm.edges if e.is_boundary]
    if be:
        groups = clusters(len(be), lambda i: [v.index for v in be[i].verts])
        loops = []
        for g in groups:
            es = [be[i] for i in g]
            per = sum(e.calc_length() for e in es)
            cen = sum(((e.verts[0].co + e.verts[1].co) / 2 for e in es), Vector()) / len(es)
            nrm = sum((e.link_faces[0].normal for e in es), Vector()).normalized()
            loops.append(dict(count=len(es), per=per, pos=cen, normal=nrm,
                              ids=ids_of([v for e in es for v in e.verts])))
        if ob.name.endswith(SKIN):
            low = min(range(len(loops)), key=lambda i: frame.slab(side, loops[i]["pos"]))
            expected = {low}
        else:
            expected = {i for i, l in enumerate(loops) if is_root_loop(ob, side, l, frame)}
        for i, l in enumerate(loops):
            out.append(dict(kind="hole_expected" if i in expected else "hole", obj=ob.name,
                            side=side, pos=l["pos"], normal=l["normal"], r=l["per"] / 6.28,
                            count=l["count"], worst="perim%.4f" % l["per"], bad=l["per"],
                            ids=l["ids"]))
    bm.free()
    return out


def is_root_loop(ob, side, loop, frame):
    """A finger tube's open root: a full ring of edges (the tubes have 12 sides); the
    2-edge loops on `_fingers` are real holes."""
    return ob.name.endswith(FINGERS_PART) and loop["count"] >= 8


def setup_render():
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.render.resolution_x = RES
    sc.render.resolution_y = RES
    sh = sc.display.shading
    sh.light = "STUDIO"
    sh.color_type = "OBJECT"
    sh.show_backface_culling = True
    sh.show_object_outline = False
    cam_d = bpy.data.cameras.new("c")
    cam_d.type = "ORTHO"
    cam = bpy.data.objects.new("cam", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam
    sc.world = sc.world or bpy.data.worlds.new("w")
    return sc, cam, cam_d


def shoot(sc, cam, cam_d, path, target, view, scale, up=None):
    """Orthographic shot looking along `view` at `target` (`up` is the image's up, default
    world Z); only geometry within 0.6 scale in front of the target is kept so occluders
    do not hide it."""
    d = view.normalized()
    if up is None:
        up = Vector((0, 0, 1))
    if abs(d.dot(up)) > 0.98:
        up = Vector((0, 1, 0))
    z = -d
    x = up.cross(z).normalized()
    y = z.cross(x)
    rot = Matrix((x, y, z)).transposed().to_4x4()
    dist = scale * 2
    cam.matrix_world = Matrix.Translation(target - d * dist) @ rot
    cam_d.ortho_scale = scale
    cam_d.clip_start = max(dist - scale * 0.6, 0.001)
    cam_d.clip_end = dist + scale * 4
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main() -> None:
    glb, out = bl_result.args()[:2]
    os.makedirs(out, exist_ok=True)
    with open(os.path.splitext(glb)[0] + ".bones.json") as fh:
        raw = json.load(fh)
    frames = {s: Frame(h) for s, h in raw.items()}
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    bpy.ops.import_scene.gltf(filepath=glb)
    meshes = [o for o in bpy.data.objects if o.type == "MESH" and o.name[:2] in ("L_", "R_")]
    lines = []
    found = []
    for ob in sorted(meshes, key=lambda o: o.name):
        side = ob.name[0]
        found += analyse(ob, side, frames[side])
    for c in found:
        fr = frames[c["side"]]
        c["bone"] = fr.nearest(c["pos"])
        c["s"] = fr.slab(c["side"], c["pos"])
    found.sort(key=lambda c: (KINDS.index(c["kind"]), c["obj"], -c["bad"]))
    seen = {}
    for c in found:
        c["n"] = seen.get((c["kind"], c["obj"]), 0)
        seen[(c["kind"], c["obj"])] = c["n"] + 1
        lines.append("%s %s %s s=%.2f count=%d worst=%s" % (
            c["kind"], c["obj"], c["bone"], c["s"], c["count"], c["worst"]))
    for k in KINDS:
        cs = [c for c in found if c["kind"] == k]
        if cs:
            lines.append("summary %s clusters=%d items=%d" % (k, len(cs), sum(c["count"] for c in cs)))
    # skinning cross-check: claws are placed by the engine, skin and tubes by the export's CPU
    # skinning, so the claw to fingers gap must not change between posed and rest exports
    for ob in sorted(meshes, key=lambda o: o.name):
        if "_claw_" not in ob.name:
            continue
        fob = [o for o in meshes if o.name[0] == ob.name[0] and o.name.endswith(FINGERS_PART)]
        if not fob:  # the one-skin hands have no separate fingers object
            continue
        mw = ob.matrix_world
        cen = sum((mw @ v.co for v in ob.data.vertices), Vector()) / len(ob.data.vertices)
        gap = min((fob[0].matrix_world @ v.co - cen).length for v in fob[0].data.vertices)
        lines.append("claw_gap %s %s %.4f" % (ob.name, os.path.basename(glb)[:-4], gap))
    with open(os.path.join(out, "hunt.txt"), "w") as fh:
        fh.write("\n".join(lines) + "\n")
    with_ids = [c for c in found if c.get("ids")]
    if with_ids:
        with open(os.path.join(out, "clusters.txt"), "w") as fh:
            for c in with_ids:
                fh.write("%s %s %s s=%.2f count=%d ids=%s\n" % (
                    c["kind"], c["obj"], c["bone"], c["s"], c["count"],
                    ",".join(str(i) for i in c["ids"])))

    sc, cam, cam_d = setup_render()
    for ob in meshes:
        ob.color = (0.70, 0.62, 0.50, 1) if ob.name[1:] == SKIN else (0.55, 0.62, 0.50, 1)
    for ob in meshes:
        ob.hide_render = False
    # orbit: 12 views per hand, azimuth every 30 degrees, elevation alternating 20 and 50
    for side, fr in frames.items():
        for ob in meshes:
            ob.hide_render = ob.name[0] != side
        h = fr.bones[VG_HAND + "." + side]
        m = fr.bones[VG_MIDDLE1 + "." + side]
        span = (m - h).length
        centre = h + (m - h) * 0.55
        for k in range(12):
            az = math.radians(30 * k)
            el = math.radians(20 if k % 2 == 0 else 50)
            view = -Vector((math.cos(az) * math.cos(el), math.sin(az) * math.cos(el), math.sin(el)))
            shoot(sc, cam, cam_d, os.path.join(out, "orbit_%s_%d.png" % (side, k)),
                  centre, view, span * 2.8)
    # close-ups: 8 worst clusters per kind, 3 angles each
    for kind in KINDS:
        if kind == "hole_expected":
            continue
        cs = [c for c in found if c["kind"] == kind]
        for c in sorted(cs, key=lambda c: -c["bad"])[:CLOSEUPS]:
            for ob in meshes:
                ob.hide_render = ob.name[0] != c["side"]
            fr = frames[c["side"]]
            span = (fr.bones[VG_MIDDLE1 + "." + c["side"]] - fr.bones[VG_HAND + "." + c["side"]]).length
            scale = max(c["r"] * 3, span * 0.08)
            n = c["normal"] if c["normal"].length > 0.5 else Vector((0, 0, 1))
            d0 = -n.normalized()
            perp = d0.cross(Vector((0, 0, 1)))
            if perp.length < 1e-3:
                perp = d0.cross(Vector((0, 1, 0)))
            perp.normalize()
            for a, ang in enumerate((0, 60, -60)):
                view = Matrix.Rotation(math.radians(ang), 3, perp) @ d0
                shoot(sc, cam, cam_d,
                      os.path.join(out, "%s_%s_%d_%d.png" % (kind, c["obj"], c["n"], a)),
                      c["pos"], view, scale)
    print("HUNT", out, len(found))
    bl_result.write("hunt", clusters=len(found))


if __name__ == "__main__":
    main()
