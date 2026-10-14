class_name RearDoorDonorIron
extends RefCounted
## Heavy iron plates under the donor leaf's home-made hinge arms (spec 5): flame-cut slabs of dark
## mill-scale iron, stitch-welded to the tread plate's backing (A, B) or clamped through the
## roofing sheet with a backing plate (C). Hinge-local metres, x 0 at the hinge.

const _LeafBuild := preload("res://scripts/van/rear_door_leaf_build.gd")
const _Skin := preload("res://scripts/van/rear_door_skin.gd")
const _Plate := preload("res://scripts/van/look/rear_door_donor_plate.gd")
const _Welds := preload("res://scripts/van/look/rear_door_donor_welds.gd")
const _Panels := preload("res://scripts/van/look/rear_door_donor_panels.gd")

const T := 0.02
const BEVEL := 0.006
const X0 := 0.04
const SIZE_A := Vector2(0.34, 0.22)
const SIZE_B := Vector2(0.30, 0.20)
## The cabin face of the tread plate's backing, where A and B sit.
const BACK_Z := _LeafBuild.STREET_HALF - _Skin.STREET_SETBACK - _Plate.THICK - 0.011 \
		- _Plate.BACKING_T
## Cabin face of A and B: the arms end against it.
const CABIN_FACE := BACK_Z - T
const BEAD_Z := BACK_Z - 0.008
const BEAD_T := 0.016


static func iron() -> Material:
	return _Panels.flat(Color(0.15, 0.14, 0.13), 0.72, 0.25)


## Plate A or B: welded on its top, bottom and leaf sides (the pillar side stays free).
static func weld_on(hinge: Node3D, size: Vector2, y: float, rng: RandomNumberGenerator,
		out: Array[Node3D]) -> void:
	var c := Vector2(X0 + size.x * 0.5, y)
	_slab(hinge, "HingeIron", size, c, BACK_Z, CABIN_FACE, out)
	var hw := size.x * 0.5
	var hh := size.y * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides: Array = [[Vector2(-hw, hh), Vector2(hw, hh), Vector2(0.0, 0.01)],
			[Vector2(hw, hh), Vector2(hw, -hh), Vector2(0.01, 0.0)],
			[Vector2(hw, -hh), Vector2(-hw, -hh), Vector2(0.0, -0.01)]]
	for side: Array in sides:
		var a: Vector2 = side[0] + c
		var b: Vector2 = side[1] + c
		var span := a.distance_to(b)
		var dir := (b - a) / span
		# Stitches: two to three runs with uneven gaps between them.
		var runs := rng.randi_range(2, 3)
		var step := span / float(runs)
		for k in runs:
			var t0 := step * k + rng.randf_range(0.0, 0.05)
			var t1 := step * (k + 1) - rng.randf_range(0.03, 0.09)
			if t1 - t0 > 0.05:
				_Welds.add_bead(st, a + dir * t0, a + dir * t1, BEAD_Z, side[2], rng, BEAD_T)
	_Panels.add(hinge, "HingeIronWeld", st.commit(), _Welds.weld_steel(), Vector3.ZERO,
			Vector3.ZERO, out)


## A slab `size` centred at `c`: flat face at `z_flat`, flame-cut bevel on the `z_bevel` face.
static func _slab(parent: Node3D, node_name: String, size: Vector2, c: Vector2, z_flat: float,
		z_bevel: float, out: Array[Node3D]) -> void:
	var z_mid := z_bevel + signf(z_flat - z_bevel) * BEVEL
	var hw := size.x * 0.5
	var hh := size.y * 0.5
	var mid := Vector3(0.0, 0.0, (z_flat + z_bevel) * 0.5)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var signs: Array[Vector2] = [Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(1.0, 1.0),
			Vector2(-1.0, 1.0)]
	var flat: Array[Vector3] = []
	var edge: Array[Vector3] = []
	var cut: Array[Vector3] = []
	for s: Vector2 in signs:
		flat.append(Vector3(s.x * hw, s.y * hh, z_flat))
		edge.append(Vector3(s.x * hw, s.y * hh, z_mid))
		cut.append(Vector3((hw - BEVEL) * s.x, (hh - BEVEL) * s.y, z_bevel))
	_quad(st, [flat[0], flat[1], flat[2], flat[3]], mid)
	_quad(st, [cut[0], cut[1], cut[2], cut[3]], mid)
	for i in 4:
		var j := (i + 1) % 4
		_quad(st, [flat[i], flat[j], edge[j], edge[i]], mid)
		_quad(st, [edge[i], edge[j], cut[j], cut[i]], mid)
	_Panels.add(parent, node_name, st.commit(), iron(), Vector3(c.x, c.y, 0.0), Vector3.ZERO,
			out)
	var node: Node3D = out.back()
	node.add_to_group(VanLighting.GROUP_EXTERIOR_LAYER)
	VanLighting.retarget_layers(node as VisualInstance3D, VanLighting.LAYER_STREET_AND_INTERIOR)


## One flat quad of a convex slab, wound clockwise seen from outside (away from `mid`).
static func _quad(st: SurfaceTool, p: Array[Vector3], mid: Vector3) -> void:
	var n := (p[1] - p[0]).cross(p[2] - p[0]).normalized()
	var out_n := n if n.dot((p[0] + p[2]) * 0.5 - mid) > 0.0 else -n
	var order: Array = [0, 1, 2, 0, 2, 3] if n.dot(out_n) < 0.0 else [0, 2, 1, 0, 3, 2]
	for k: int in order:
		st.set_normal(out_n)
		st.add_vertex(p[k])
