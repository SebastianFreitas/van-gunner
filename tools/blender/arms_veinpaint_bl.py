"""Paint renders for `arms.py veinpaths`: old and new vein paths as vertex colour on a skin copy."""
import math
import os
import re
import sys

import bpy
import numpy as np

from arm_names import photo_path, UV_A, UV_B, SKIN, RIG
from arms_frame_bl import hand_frame  # noqa: E402
from arms_veinmesh import VeinMesh  # noqa: E402
import arms_veingates as G  # noqa: E402
from arms_hunt_bl import setup_render, shoot  # noqa: E402
from arms_veinsplice import NAME, RES  # noqa: E402

WRAP = 2 * math.pi * 0.035
GREY = np.array((0.55, 0.55, 0.55))
RED = np.array((0.9, 0.04, 0.04))
BLUE = np.array((0.08, 0.2, 0.95))
S_LO, S_HI = -0.2, 2.2  # arms_look_bl's framing


# The photo's rows in px (600 x 900, y down), read once from the picture: knuckle-row top and
# dorsal wrist crease per fist (hand length 170 px L, 180 px R, research 05), and the fist's
# centre column; our L is the photo's left half (x < 300), our R its right half.
PH_KNUCKLE = {"L": 283, "R": 293}
PH_WRIST = {"L": 453, "R": 473}
PH_CX = {"L": 200, "R": 430}
PH_X0 = {"L": 0, "R": 300}
PH_X1 = {"L": 300, "R": 600}
SHEET_S = (-1.9, 1.1)


def _read(side: str, suffix: str, res: str = RES) -> list:
    """The paths of <res>/vein_set_<side><suffix>.tres as lists of (x, v, r)."""
    with open(os.path.join(res, "vein_set_%s%s.tres" % (NAME[side], suffix))) as fh:
        text = fh.read()
    body = re.search(r"^paths = Array\[PackedVector3Array\]\(\[(.*)\]\)$", text, re.M).group(1)
    paths = []
    for p in re.findall(r"PackedVector3Array\(([^)]*)\)", body):
        v = [float(x) for x in p.split(",")]
        paths.append([tuple(v[i:i + 3]) for i in range(0, len(v), 3)])
    return paths


def _bump(ch, w, pts) -> np.ndarray:
    """Per vertex max of h = w (r/.006)(1 - q^2)^2, q = d/(2.26 r), over the segments of pts."""
    h = np.zeros(len(ch))
    for a, b in zip(pts, pts[1:]):
        ab = np.array((b[0] - a[0], b[1] - a[1]))
        dv = ch[:, 1] - a[1]
        dv -= WRAP * np.round(dv / WRAP)
        rel = np.stack((ch[:, 0] - a[0], dv), axis=1)
        t = np.clip(rel @ ab / (ab @ ab + 1e-18), 0.0, 1.0)
        d = np.hypot(*(rel - t[:, None] * ab).T)
        r = a[2] + t * (b[2] - a[2])
        q = d / (2.26 * r)
        h = np.maximum(h, np.where(q < 1, w * (r / 0.006) * (1 - q * q) ** 2, 0.0))
    return h


def _trace(ch, pts, min_hw: float = 0.0025, dot: bool = True) -> tuple:
    """(brightness, dots) per vertex: full red where q < 1 with half-width at least min_hw."""
    br = np.zeros(len(ch))
    dots = np.zeros(len(ch), dtype=bool)
    for a, b in zip(pts, pts[1:]):
        ab = np.array((b[0] - a[0], b[1] - a[1]))
        dv = ch[:, 1] - a[1]
        dv -= WRAP * np.round(dv / WRAP)
        rel = np.stack((ch[:, 0] - a[0], dv), axis=1)
        t = np.clip(rel @ ab / (ab @ ab + 1e-18), 0.0, 1.0)
        d = np.hypot(*(rel - t[:, None] * ab).T)
        hw = np.maximum(2.26 * (a[2] + t * (b[2] - a[2])), min_hw)
        q = d / hw
        br = np.maximum(br, np.where(q < 1, 0.45 + 0.55 * (1 - q * q) ** 2, 0.0))
    for a in pts if dot else ():
        dv = ch[:, 1] - a[1]
        dv -= WRAP * np.round(dv / WRAP)
        dots |= np.hypot(ch[:, 0] - a[0], dv) < 0.0015
    return br, dots


def _cords(side: str, mesh) -> list:
    """Each cord as chart points (x, v, r) at Gate 5's radius."""
    G.MESH = mesh
    try:
        line, rr = G.cords(side)
        out = []
        for k in G.ORDER:
            a, b = line[k]
            pts = []
            for t in np.linspace(0.0, 1.0, 25):
                c = G.chart(side, (a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1])))
                pts.append((c[0], c[1], max(rr[k](t), 1e-4)))
            out.append(pts)
        return out
    finally:
        G.MESH = None


def _setup(side: str) -> tuple:
    """(scene, camera, camera data, mesh copy) of the skin as a flat vertex-colour render."""
    sc, cam, cam_d = setup_render()
    sc.render.resolution_x = 1024
    sc.render.resolution_y = 1024
    sh = sc.display.shading
    sh.light = "FLAT"
    sh.color_type = "VERTEX"
    bpy.data.objects[RIG].data.pose_position = "REST"
    src = bpy.data.objects[side + SKIN]
    ev = src.evaluated_get(bpy.context.evaluated_depsgraph_get())
    me = bpy.data.meshes.new_from_object(ev)
    ob = bpy.data.objects.new("paint_" + side, me)
    ob.matrix_world = ev.matrix_world
    sc.collection.objects.link(ob)
    for o in bpy.data.objects:
        o.hide_render = o is not ob
    return sc, cam, cam_d, me


TEXEL = 1.5e-4  # chart units per chart-image texel, well under the thinnest w_vis (about .0019)
PAD = 0.4  # radians of chart image past +-pi, so a face across the angle seam is unwrapped


def _paint(cov: np.ndarray, bri: np.ndarray, pts: list, k: float, x0: float, ang0: float,
           span: float) -> None:
    """One path's segments into the coverage and brightness grids, with the shader's soft edge
    (smoothstep over the outer quarter of the half-width) and the true half-width 2.26 r."""
    h, w = cov.shape
    for a, b in zip(pts, pts[1:]):
        m = 2.26 * max(a[2], b[2]) + TEXEL
        xs = (min(a[0], b[0]) - m - x0, max(a[0], b[0]) + m - x0)
        vs = ((min(a[1], b[1]) - m - k) / 0.035 - ang0, (max(a[1], b[1]) + m - k) / 0.035 - ang0)
        c0, c1 = max(int(xs[0] / TEXEL), 0), min(int(xs[1] / TEXEL) + 1, w)
        r0, r1 = max(int(vs[0] / span * h), 0), min(int(vs[1] / span * h) + 1, h)
        if c0 >= c1 or r0 >= r1:
            continue
        px = x0 + (np.arange(c0, c1) + 0.5) * TEXEL
        pv = 0.035 * (ang0 + (np.arange(r0, r1) + 0.5) / h * span) + k
        rel = np.stack(np.broadcast_arrays(px[None, :] - a[0], pv[:, None] - a[1]), axis=-1)
        ab = np.array((b[0] - a[0], b[1] - a[1]))
        t = np.clip(rel @ ab / (ab @ ab + 1e-18), 0.0, 1.0)
        d = np.hypot(*(rel - t[..., None] * ab).transpose(2, 0, 1))
        q = d / (2.26 * (a[2] + t * (b[2] - a[2])))
        e = np.clip((q - 0.75) / 0.25, 0.0, 1.0)
        c = 1.0 - e * e * (3.0 - 2.0 * e)
        core = 0.45 + 0.55 * (1 - np.minimum(q, 1.0) ** 2) ** 2
        cov[r0:r1, c0:c1] = np.maximum(cov[r0:r1, c0:c1], c)
        bri[r0:r1, c0:c1] = np.maximum(bri[r0:r1, c0:c1], core * (q < 1))


def _chart_image(side: str, mesh, paths: list, me) -> None:
    """Per pixel like arm_vein.gdshaderinc: the vein brightness on an (x, angle) grid, sampled
    bilinear through a UV layer made from each loop's chart (UV_A / UV_B in arm_names), not interpolated
    per vertex. The grid reaches PAD past +-pi and a face that crosses the seam is shifted whole."""
    x0, x1 = float(mesh.ch[:, 0].min()) - 0.01, float(mesh.ch[:, 0].max()) + 0.01
    ang0, span = -math.pi - PAD, 2 * (math.pi + PAD)
    w = max(int(math.ceil((x1 - x0) / TEXEL)), 1)
    h = int(math.ceil(span * 0.035 / TEXEL))
    cov, bri = np.zeros((h, w), np.float32), np.zeros((h, w), np.float32)
    for pts in paths:
        for k in (0.0, WRAP, -WRAP):  # a vein near the +-pi seam also shows on the other side
            _paint(cov, bri, pts, k, x0, ang0, span)
    col = GREY * (1 - cov[..., None]) + RED * (bri * cov)[..., None]
    img = bpy.data.images.new("veinchart_" + side, w, h, alpha=False)
    img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(np.concatenate((col, np.ones((h, w, 1))), axis=2)
                           .astype(np.float32).ravel())
    n = len(me.loops)
    a, b = np.zeros(2 * n), np.zeros(2 * n)
    me.uv_layers[UV_A].data.foreach_get("uv", a)
    me.uv_layers[UV_B].data.foreach_get("uv", b)
    a, b = a.reshape(n, 2), b.reshape(n, 2)
    ang = np.arctan2(b[:, 0], 1 - a[:, 1])
    ls, lt = np.zeros(len(me.polygons), np.int32), np.zeros(len(me.polygons), np.int32)
    me.polygons.foreach_get("loop_start", ls)
    me.polygons.foreach_get("loop_total", lt)
    lo, hi = np.minimum.reduceat(ang, ls), np.maximum.reduceat(ang, ls)
    cross = np.repeat(hi - lo > math.pi, lt)  # loops are in polygon order
    ang = np.where(cross & (ang < 0), ang + 2 * math.pi, ang)
    uv = me.uv_layers[UV_A]  # the copy is at the UV layer limit: reuse one, chart is read
    uv.data.foreach_set("uv", np.stack(((a[:, 0] - x0) / (w * TEXEL),
                                        (ang - ang0) / span), axis=1).ravel())
    me.uv_layers.active = uv
    mat = bpy.data.materials.new("veinchart_" + side)
    mat.use_nodes = True
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image, tex.interpolation, tex.extension = img, "Linear", "EXTEND"
    mat.node_tree.links.new(tex.outputs["Color"],
                            mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    me.materials.append(mat)


def render_set(side: str, mesh, paths: list, out_png: str, s_range: tuple = (S_LO, S_HI)) -> None:
    """Back view of `paths` at true width (no minimum half-width, no dots) over s_range, drawn per
    pixel in chart space the way the game's vein shader does."""
    sc, cam, cam_d, me = _setup(side)
    sc.display.shading.color_type = "TEXTURE"
    _chart_image(side, mesh, paths, me)
    fr = hand_frame(side)
    centre = fr.point((s_range[0] + s_range[1]) / 2)
    scale = (s_range[1] - s_range[0]) * fr.span * 1.04
    shoot(sc, cam, cam_d, out_png, centre, -fr.dors, scale, fr.axis)


def _pixels(path: str) -> np.ndarray:
    """(h, w, 4) float rows top first, no colour conversion."""
    img = bpy.data.images.load(path)
    img.colorspace_settings.name = "Non-Color"
    w, h = img.size
    return np.array(img.pixels[:]).reshape(h, w, 4)[::-1]


def sheet(side: str, out_dir: str, traced_png: str, rejected_png: str) -> str:
    """Writes <out_dir>/sheet_<side>_back.png: the owner's photo fist | traced | rejected."""
    tr, rj = _pixels(traced_png), _pixels(rejected_png)
    n = tr.shape[0]
    ph = _pixels(photo_path())
    pps = n / ((SHEET_S[1] - SHEET_S[0]) * 1.04)  # render pixels per s
    lpx = PH_WRIST[side] - PH_KNUCKLE[side]  # photo pixels per s
    k = lpx / pps
    ys = (n - 1) / 2 + (SHEET_S[1] + SHEET_S[0]) / 2 * pps - np.arange(n)  # dest row -> s * pps
    src_y = np.rint(PH_WRIST[side] - ys / pps * lpx).astype(int)
    src_x = np.rint(PH_CX[side] + (np.arange(n) - (n - 1) / 2) * k).astype(int)
    oky = (src_y >= 0) & (src_y < ph.shape[0])
    okx = (src_x >= PH_X0[side]) & (src_x < PH_X1[side])
    pan = ph[np.clip(src_y, 0, ph.shape[0] - 1)][:, np.clip(src_x, 0, ph.shape[1] - 1)].copy()
    pan[~oky] = 0.0
    pan[:, ~okx] = 0.0
    pan[..., 3] = 1.0
    sh = np.concatenate((pan, tr, rj), axis=1)
    img = bpy.data.images.new("sheet_" + side, sh.shape[1], n, alpha=False)
    img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(sh[::-1].astype(np.float32).ravel())
    img.filepath_raw = os.path.join(out_dir, "sheet_%s_back.png" % side)
    img.file_format = "PNG"
    img.save()
    return img.filepath_raw


def paint(side: str, mesh, out: str) -> list:
    """Writes <out>/paint_<side>_<back|side>_<before|after>.png and returns the file names."""
    sc, cam, cam_d, me = _setup(side)
    w = np.clip(1.0 - mesh.wmax, 0.0, 1.0)  # veins fade into the finger-weighted skin
    cords = _cords(side, mesh)
    hc = np.zeros(len(mesh.ch))
    for pts in cords:
        hc = np.maximum(hc, _bump(mesh.ch, w, pts))
    attr = me.color_attributes.new("paint", "FLOAT_COLOR", "POINT")
    fr = hand_frame(side)
    centre = fr.point((S_LO + S_HI) / 2)
    scale = (S_HI - S_LO) * fr.span * 1.04
    names = []
    for which, suffix in (("before", ""), ("after", "_next")):
        hv = np.zeros(len(mesh.ch))
        for pts in _read(side, suffix):
            hv = np.maximum(hv, _bump(mesh.ch, w, pts))
        a_c = np.clip(hc, 0, 1)[:, None]
        a_v = np.clip(hv, 0, 1)[:, None]
        col = GREY * (1 - a_c) + BLUE * a_c
        col = col * (1 - a_v) + RED * a_v
        rgba = np.concatenate((col, np.ones((len(col), 1))), axis=1)
        attr.data.foreach_set("color", rgba.ravel())
        me.color_attributes.active_color = attr
        for view, vec in (("back", -fr.dors), ("side", -fr.lat)):
            fn = "paint_%s_%s_%s.png" % (side, view, which)
            shoot(sc, cam, cam_d, os.path.join(out, fn), centre, vec, scale, fr.axis)
            names.append(fn)
        br = np.zeros(len(mesh.ch))
        dots = np.zeros(len(mesh.ch), dtype=bool)
        for pts in _read(side, suffix):
            b, d = _trace(mesh.ch, pts)
            br = np.maximum(br, b)
            dots |= d
        a_t = (br > 0)[:, None]
        col = np.where(a_t, RED * br[:, None], GREY)
        col = np.where(dots[:, None], 0.0, col)
        rgba = np.concatenate((col, np.ones((len(col), 1))), axis=1)
        attr.data.foreach_set("color", rgba.ravel())
        for view, vec in (("back", -fr.dors), ("side", -fr.lat)):
            fn = "paint_%s_%s_%s_trace.png" % (side, view, which)
            shoot(sc, cam, cam_d, os.path.join(out, fn), centre, vec, scale, fr.axis)
            names.append(fn)
    return names


def main(args: list) -> None:
    """`-- <out_dir> <scratch_dir>`: true-width live and scratch _next renders and the sheets."""
    out, scratch = args[:2]
    os.makedirs(out, exist_ok=True)
    for side in ("R", "L"):
        mesh = VeinMesh(side)
        tr = os.path.join(out, "traced_%s_back.png" % side)
        rj = os.path.join(out, "rejected_%s_back.png" % side)
        render_set(side, mesh, _read(side, "_next", scratch), tr, SHEET_S)
        render_set(side, mesh, _read(side, ""), rj, SHEET_S)
        print("SHEET", sheet(side, out, tr, rj))


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:])
