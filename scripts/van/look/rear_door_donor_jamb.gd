class_name RearDoorDonorJamb
extends RefCounted
## Hand-cut filler strip welded on the donor side's pillar ramp (spec 7): its door-side edge is
## ragged so it meets the scrap patches with an uneven dark gap, its wall side carries a heavy bead.

const _Ramp := preload("res://scripts/van/rear_door_ramp.gd")
const _Surround := preload("res://scripts/van/rear_door_surround.gd")
const _LeafBuild := preload("res://scripts/van/rear_door_leaf_build.gd")
const _Panels := preload("res://scripts/van/look/rear_door_donor_panels.gd")
const _Welds := preload("res://scripts/van/look/rear_door_donor_welds.gd")
## Slope distance of the strip's door-side edge from the ramp's lower crease (clear of its bevel).
const U0 := 0.04
const WIDTH := 0.12
const THICK := 0.012
## The strip stands off the ramp (tack-welded) so its faces stay over 1 cm from the bracket plate's.
const SINK := -0.003
const ROWS := 7
## Straight part of the pillar: clear of the rounded opening corners.
const Y_LOW := 0.25
const TOP_CLEAR := 0.45


## Builds the strip under the portal beside `hinge` (the donor, x<0) and returns the nodes added.
static func build(hinge: Node3D, rng: RandomNumberGenerator) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var host := hinge.get_parent().get_node_or_null("Portal") as Node3D
	if host == null:
		return out
	var z_in := hinge.position.z + _LeafBuild.CABIN_Z
	var z_deep := _Ramp.z_deep_rel() + hinge.position.z
	var s := signf(hinge.position.x)
	var f := _Ramp.frame(Vector2(hinge.position.x + s * _Surround.RAMP_IN, 0.0),
			Vector2(s, 0.0), z_in, z_in, z_deep)
	var root := Node3D.new()
	root.name = "DonorJamb"
	# Canted 5 degrees about its middle: hand-fitted, and never parallel to the bracket plate.
	var pivot := Vector3(U0 + WIDTH * 0.5, 0.0, 0.0)
	root.transform = f * Transform3D(Basis(Vector3.UP, deg_to_rad(-5.0)), pivot) \
			* Transform3D(Basis.IDENTITY, -pivot)
	host.add_child(root)
	out.append(root)
	# Local y is world up or down depending on the side: rows are laid out in world y.
	var ysign := signf(f.basis.y.y)
	var y0 := Y_LOW
	var y1 := VanInteriorSize.REAR_DOOR_TOP - TOP_CLEAR
	var rows: Array[Vector3] = []
	for i in ROWS:
		var y := lerpf(y0, y1, float(i) / float(ROWS - 1)) + rng.randf_range(-0.05, 0.05) * (
				1.0 if i > 0 and i < ROWS - 1 else 0.0)
		rows.append(Vector3(U0 + rng.randf_range(0.0, 0.02), y * ysign, U0 + WIDTH))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var zf := -(THICK - SINK)
	for i in ROWS - 1:
		_row(st, rows[i], rows[i + 1], zf, SINK)
	_Panels.add(root, "JambStrip", st.commit(), _Panels.flat(Color(0.15, 0.14, 0.13), 0.85, 0.2),
			Vector3.ZERO, Vector3.ZERO, out)
	var wst := SurfaceTool.new()
	wst.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in ROWS - 1:
		var a := rows[i]
		var b := rows[i + 1]
		_Welds.add_bead(wst, Vector2(a.z, a.y), Vector2(b.z, b.y), zf - _Welds.BEAD_H * 0.9,
				Vector2.ZERO, rng, _Welds.BEAD_H * 1.6)
	_Panels.add(root, "JambBead", wst.commit(), _Welds.weld_steel(), Vector3.ZERO, Vector3.ZERO,
			out)
	var disc := CylinderMesh.new()
	disc.top_radius = _Welds.PLUG_R
	disc.bottom_radius = _Welds.PLUG_R * 1.15
	disc.height = _Welds.BEAD_H
	disc.radial_segments = 8
	disc.rings = 1
	var mid_u := U0 + WIDTH * 0.5 + 0.01
	for t: float in [0.27, 0.71]:
		var y := lerpf(y0, y1, t) * ysign
		_Panels.add(root, "JambPlug", disc, _Welds.weld_steel(),
				Vector3(mid_u + rng.randf_range(-0.01, 0.01), y, zf - _Welds.BEAD_H * 0.6),
				Vector3(PI * 0.5, 0.0, 0.0), out)
	var bolt := CylinderMesh.new()
	bolt.top_radius = 0.03
	bolt.bottom_radius = 0.03
	bolt.height = 0.02
	bolt.radial_segments = 6
	bolt.rings = 1
	_Panels.add(root, "JambBolt", bolt, _Welds.weld_steel(),
			Vector3(mid_u, lerpf(y0, y1, 0.5) * ysign, zf - 0.011), Vector3(PI * 0.5, 0.0, 0.0), out)
	return out


## One slab between two ragged rows (x = door-side edge, y, z = wall-side edge), local frame.
static func _row(st: SurfaceTool, a: Vector3, b: Vector3, zf: float, zb: float) -> void:
	var p: Array[Vector3] = [Vector3(a.x, a.y, zf), Vector3(a.z, a.y, zf),
			Vector3(b.z, b.y, zf), Vector3(b.x, b.y, zf),
			Vector3(a.x, a.y, zb), Vector3(a.z, a.y, zb),
			Vector3(b.z, b.y, zb), Vector3(b.x, b.y, zb)]
	var mid := Vector3.ZERO
	for v in p:
		mid += v / 8.0
	for q: Array in [[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6],
			[3, 0, 4, 7]]:
		_quad(st, [p[q[0]], p[q[1]], p[q[2]], p[q[3]]], mid)


## One flat quad wound clockwise seen from outside (away from `mid`).
static func _quad(st: SurfaceTool, p: Array[Vector3], mid: Vector3) -> void:
	var n := (p[1] - p[0]).cross(p[2] - p[0]).normalized()
	var out_n := n if n.dot((p[0] + p[2]) * 0.5 - mid) > 0.0 else -n
	var order: Array = [0, 1, 2, 0, 2, 3] if n.dot(out_n) < 0.0 else [0, 2, 1, 0, 3, 2]
	for k: int in order:
		st.set_normal(out_n)
		st.add_vertex(p[k])
