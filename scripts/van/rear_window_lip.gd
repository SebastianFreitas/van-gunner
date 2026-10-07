extends RefCounted
## Rear window lip: dark lip riding on each rear leaf, closing the slot between the vaulted skin and the window's cabin frame.

const _LeafBuild := preload("res://scripts/van/rear_door_leaf_build.gd")

## Window centre height in rig space, as `rear_door_leaf_build.gd` cuts the hole (left leaf).
const HOLE_CENTER_RIG_Y := 1.775
## How far the lip covers the skin past the hole edge.
const OVER_SKIN := 0.05
## How far the lip reaches into the glass: to the cabin frame's inner cut.
const INTO_GLASS := 0.07
## Back face sunk into the skin so no slit opens under the lip.
const SINK := 0.02
## Street face proud of the skin, more than 1 cm so the two never share a depth plane.
const PROUD := 0.015
## Outer edge kept this far inside the leaf's centre edge.
const INNER_EDGE_CLEAR := 0.01
## Sleeve ring sits this far outside the hole edge so it never shares a plane with the slab's own returns.
const SLEEVE_OFFSET := 0.01


## Adds the dark window lip to one rear leaf (left-hinge-local, mirrored for the right).
static func build(left_hinge: Node3D, hinge: Node3D, mirror_x: bool) -> void:
	if left_hinge == null or hinge == null:
		return
	var old := hinge.get_node_or_null("WindowLip")
	if old != null:
		old.free()
	var center := Vector2(_LeafBuild.WINDOW_X,
			HOLE_CENTER_RIG_Y - left_hinge.position.y)
	var max_x := absf(left_hinge.position.x) - _LeafBuild.CENTER_GAP - INNER_EDGE_CLEAR
	var outer := _ring(OVER_SKIN)
	var inner := _ring(-INTO_GLASS)
	var sleeve := _ring(SLEEVE_OFFSET)
	for i in outer.size():
		var o := outer[i] + center
		outer[i] = Vector2(minf(o.x, max_x), o.y)
		inner[i] += center
		var s := sleeve[i] + center
		sleeve[i] = Vector2(minf(s.x, max_x), s.y)
	var z_front := _LeafBuild.DOOR_THICKNESS * 0.5 + PROUD
	var z_back := _LeafBuild.DOOR_THICKNESS * 0.5 - SINK
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := outer.size()
	for k in count:
		var n := (k + 1) % count
		var ok := outer[k]
		var on := outer[n]
		var ik := inner[k]
		var inn := inner[n]
		var outer_mid := (ok + on) * 0.5
		var inner_mid := (ik + inn) * 0.5
		_quad(st, Vector3(ok.x, ok.y, z_front), Vector3(on.x, on.y, z_front),
				Vector3(inn.x, inn.y, z_front), Vector3(ik.x, ik.y, z_front), Vector3.BACK)
		var sk := sleeve[k]
		var sn := sleeve[n]
		_quad(st, Vector3(ok.x, ok.y, z_back), Vector3(on.x, on.y, z_back),
				Vector3(sn.x, sn.y, z_back), Vector3(sk.x, sk.y, z_back), Vector3.FORWARD)
		_quad(st, Vector3(sk.x, sk.y, z_back), Vector3(sn.x, sn.y, z_back),
				Vector3(inn.x, inn.y, z_back), Vector3(ik.x, ik.y, z_back), Vector3.FORWARD)
		_quad(st, Vector3(ik.x, ik.y, z_back), Vector3(inn.x, inn.y, z_back),
				Vector3(inn.x, inn.y, z_front), Vector3(ik.x, ik.y, z_front),
				_perp(ik, inn, inner_mid - outer_mid))
		_quad(st, Vector3(ok.x, ok.y, z_back), Vector3(on.x, on.y, z_back),
				Vector3(on.x, on.y, z_front), Vector3(ok.x, ok.y, z_front),
				_perp(ok, on, outer_mid - inner_mid))
	# The slab leaves its outer hole edge open, so rays inside the hole reach the cavity between its faces.
	var z_cabin := -_LeafBuild.DOOR_THICKNESS * 0.5
	for k in count:
		var n := (k + 1) % count
		var sk := sleeve[k]
		var sn := sleeve[n]
		_quad(st, Vector3(sk.x, sk.y, z_cabin), Vector3(sn.x, sn.y, z_cabin),
				Vector3(sn.x, sn.y, z_back), Vector3(sk.x, sk.y, z_back),
				_perp(sk, sn, center - (sk + sn) * 0.5))
	st.generate_tangents()
	var node := MeshInstance3D.new()
	node.name = "WindowLip"
	node.mesh = st.commit()
	node.material_override = _material(left_hinge)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	node.layers = 1
	node.add_to_group(VanLighting.GROUP_EXTERIOR_LAYER)
	if mirror_x:
		node.scale = Vector3(-1.0, 1.0, 1.0)
	hinge.add_child(node)


## The window hole outline offset by `d` (positive outward) with mitred corners.
static func _ring(d: float) -> PackedVector2Array:
	var hole := _LeafBuild.WINDOW_HOLE
	var count := hole.size()
	var pts := PackedVector2Array()
	for i in count:
		var p := hole[(i + count - 1) % count]
		var v := hole[i]
		var q := hole[(i + 1) % count]
		var n1 := _edge_normal(p, v)
		var n2 := _edge_normal(v, q)
		var m := (n1 + n2).normalized()
		pts.append(v + m * d / maxf(m.dot(n1), 0.5))
	return pts


## Outward unit normal of edge a->b, away from the origin (the hole's centroid).
static func _edge_normal(a: Vector2, b: Vector2) -> Vector2:
	var seg := b - a
	var nrm := Vector2(seg.y, -seg.x).normalized()
	if nrm.dot((a + b) * 0.5) < 0.0:
		nrm = -nrm
	return nrm


## Two triangles for one quad, both facing `out`.
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		out: Vector3) -> void:
	_tri(st, a, b, c, out)
	_tri(st, a, c, d, out)


## Godot front faces are clockwise seen from outside, so flip any triangle that isn't.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3) -> void:
	var second := b
	var third := c
	if (c - a).cross(b - a).dot(out) < 0.0:
		second = c
		third = b
	for p in [a, second, third]:
		var pv := p as Vector3
		st.set_normal(out)
		st.set_uv(Vector2(pv.x, pv.y))
		st.add_vertex(pv)


## In-plane perpendicular of segment a->b, flipped to face along `away`.
static func _perp(a: Vector2, b: Vector2, away: Vector2) -> Vector3:
	var seg := b - a
	var perp := Vector2(seg.y, -seg.x)
	if perp.dot(away) < 0.0:
		perp = -perp
	return Vector3(perp.x, perp.y, 0.0).normalized()


## The handle mount's steel, else the leaf body's, so the lip matches the doors.
static func _material(left_hinge: Node3D) -> Material:
	var mount := left_hinge.get_node_or_null("Handle/Mount")
	if mount != null:
		var mat := mount.get("material") as Material
		if mat != null:
			return mat
	var body := left_hinge.get_node_or_null("CurvedBody") as GeometryInstance3D
	if body != null:
		return body.material_override
	return null
