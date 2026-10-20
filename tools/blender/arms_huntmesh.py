"""Mesh helpers of arms_hunt_bl: coincident faces, vertex-ring fit and the baked-id KD tree."""
from mathutils import Vector
from mathutils.kdtree import KDTree

MERGE = 1e-6


def face_elems(bm, faces):
    return [(f.calc_center_median(), f.normal.copy()) for f in faces]


def find_coincident(bm):
    groups = {}
    for f in bm.faces:
        key = tuple(sorted((round(v.co.x / MERGE), round(v.co.y / MERGE), round(v.co.z / MERGE))
                           for v in f.verts))
        groups.setdefault(key, []).append(f)
    flagged = []
    mult = []
    for fs in groups.values():
        if len(fs) > 1:
            flagged += fs
            mult += [len(fs)] * len(fs)
    return flagged, mult


def ring_info(v):
    """(height off the plane fitted to the ring, mean ring edge) or None."""
    if v.is_boundary or not v.is_manifold or len(v.link_faces) < 3:
        return None
    pts = []
    for lp in v.link_loops:
        if len(lp.face.verts) != 3:
            return None
        pts.append((lp.link_loop_next.vert.co, lp.link_loop_next.link_loop_next.vert.co))
    c = sum((a for a, _ in pts), Vector()) / len(pts)
    n = Vector()
    edge = 0.0
    for a, b in pts:
        n += (a - c).cross(b - c)
        edge += (a - b).length
    edge /= len(pts)
    if n.length < 1e-12 or edge < 1e-12:
        return None
    return abs((v.co - c).dot(n.normalized())), edge, n.normalized()


def id_tree(ob):
    """KDTree of the raw world positions holding each vertex's baked id (UV2.x), or None."""
    me = ob.data
    if len(me.uv_layers) < 2:
        return None
    uv = me.uv_layers[1].data
    ids = {}
    for lp in me.loops:
        ids.setdefault(lp.vertex_index, set()).add(int(round(uv[lp.index].uv.x)))
    tree = KDTree(len(me.vertices))
    for v in me.vertices:
        tree.insert(ob.matrix_world @ v.co, v.index)
    tree.balance()
    return tree, ids
