extends RefCounted
## Thin street-side rubber lip round the donor rear window (old VW T2 / Bedford style), fuller at
## each corner; the glass sits under its inner edge (shape only; the grime shader comes later).

const _LeafBuild := preload("res://scripts/van/rear_door_leaf_build.gd")
const _Skin := preload("res://scripts/van/rear_door_skin.gd")
const _SHADER := preload("res://scenes/van/van_gasket.gdshader")

## How far the lip reaches over the hole (the glass edge tucks under it).
const INWARD := 0.010
## How far the lip spreads onto the skin.
const OUTWARD := 0.005
## Lip back sunk into the skin so no slit opens under it.
const SINK := 0.005
## Extra width (m) and crown height (m) at the middle of a corner arc, on top of 1.5 cm / 0.4 cm.
const CORNER_WIDTH := 0.020
const CORNER_CROWN := 0.002
## Lip front profile (offset along the outline normal, height proud of the skin) from the inner
## tip to the skin edge: a wedge 0.004 proud at the crown with knife edges at both ends. No face
## is vertical or within 10 degrees of the skin or the glass, so the audit finds no FLICKER (a
## 5 mm wall at the skin edge sat 9 mm from the glass edge wall).
const FRONT: Array[Vector2] = [Vector2(-INWARD, 0.0), Vector2(0.0, 0.004), Vector2(OUTWARD, 0.0)]


## Adds the gasket node under the donor hinge `left`, following the donor's window outline.
static func build(left: Node3D, donor: RearDoorProfile) -> void:
	if left == null:
		return
	var old := left.get_node_or_null("WindowGasket")
	if old != null:
		old.free()
	var hole := donor.window_hole
	var count := hole.size()
	var sign_out := 1.0 if _area(hole) > 0.0 else -1.0
	var norms := PackedVector2Array()
	var miters := PackedFloat32Array()
	for i in count:
		var n1 := _edge_normal(hole[(i + count - 1) % count], hole[i], sign_out)
		var n2 := _edge_normal(hole[i], hole[(i + 1) % count], sign_out)
		var m := (n1 + n2).normalized()
		norms.append(m)
		miters.append(1.0 / maxf(m.dot(n1), 0.5))
	var z_street := _LeafBuild.STREET_HALF - _Skin.STREET_SETBACK
	var weights := _corner_weights(count)
	var sections: Array[Array] = []
	for k in count:
		sections.append(_section(z_street, weights[k]))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in count:
		var n := (k + 1) % count
		var section: Array = sections[k]
		for e in section.size():
			var f := (e + 1) % section.size()
			var dd: float = section[f].x - section[e].x
			var dz: float = section[f].y - section[e].y
			var quad: Array[Vector3] = []
			var nrm: Array[Vector3] = []
			for pair: Array in [[k, e], [n, e], [n, f], [k, f]]:
				var ring: int = pair[0]
				var s: Vector2 = sections[ring][pair[1]]
				var xy := hole[ring] + norms[ring] * s.x * miters[ring]
				quad.append(Vector3(xy.x, xy.y, s.y))
				nrm.append(Vector3(norms[ring].x * dz, norms[ring].y * dz, -dd).normalized())
			for tri: Array in [[0, 1, 2], [0, 2, 3]]:
				var order: Array = tri
				var face := (quad[tri[1]] - quad[tri[0]]).cross(quad[tri[2]] - quad[tri[0]])
				# Godot front faces are clockwise from outside: flip any that are not.
				if face.dot(nrm[tri[0]] + nrm[tri[1]] + nrm[tri[2]]) > 0.0:
					order = [tri[0], tri[2], tri[1]]
				for idx: int in order:
					st.set_normal(nrm[idx])
					st.add_vertex(quad[idx])
	var node := MeshInstance3D.new()
	node.name = "WindowGasket"
	node.mesh = st.commit()
	node.material_override = _material()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	node.layers = VanLighting.LAYER_STREET_AND_INTERIOR
	node.add_to_group(VanLighting.GROUP_EXTERIOR_LAYER)
	node.position = Vector3(_LeafBuild.WINDOW_X, VanOpenings.REAR_WINDOW_Y - left.position.y, 0.0)
	left.add_child(node)


## Corner weight sin(pi k / n) per hole vertex: 0 at the ends of each corner arc, 1 mid-arc. The
## hole is four corner arcs (bottom, top, top, bottom) and nothing else.
static func _corner_weights(count: int) -> PackedFloat32Array:
	var steps: Array[int] = [RearDoorProfile.DONOR_WIN_BOTTOM_STEPS,
			RearDoorProfile.DONOR_WIN_TOP_STEPS, RearDoorProfile.DONOR_WIN_TOP_STEPS,
			RearDoorProfile.DONOR_WIN_BOTTOM_STEPS]
	var w := PackedFloat32Array()
	for n in steps:
		for k in n + 1:
			w.append(sin(PI * float(k) / float(n)))
	if w.size() != count:
		w.resize(count)
	return w


## The closed cross-section in (offset, z), counter-clockwise: the street bead only, its belly
## sunk `SINK` into the skin at the hole edge. `w` (0..1) fattens it towards a corner's middle.
static func _section(z_street: float, w: float) -> Array[Vector2]:
	var ws := (0.015 + CORNER_WIDTH * w) / 0.015
	var hs := (0.004 + CORNER_CROWN * w) / 0.004
	var pts: Array[Vector2] = []
	pts.append(Vector2(0.0, z_street - SINK))
	for i in range(FRONT.size() - 1, -1, -1):
		pts.append(Vector2(FRONT[i].x * ws, z_street + FRONT[i].y * hs))
	return pts


static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return a


## Unit normal of edge a->b pointing away from the hole; `sign_out` is +1 for a counter-clockwise outline.
static func _edge_normal(a: Vector2, b: Vector2, sign_out: float) -> Vector2:
	var seg := b - a
	return Vector2(seg.y, -seg.x).normalized() * sign_out


static func _material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _SHADER
	return mat
