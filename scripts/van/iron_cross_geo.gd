extends RefCounted
## Mesh builder for IronCross: bars, plate, pads and rivets that follow the bowed side wall.

## Rivet head: a low cone, so no flat face over 1 cm² sits parallel to the exterior pane.
const RIVET_TOP_RADIUS := 0.004
const RIVET_HEIGHT := 0.006

const BOLT_RADIUS := 0.011
## Hex top under 1 cm² so it never trips the audit's FLICKER rule.
const BOLT_TOP_RADIUS := 0.0055
const BOLT_HEIGHT := 0.009
const BOLT_SINK := 0.002

## Wall profile to follow (null = flat) and the window centre height in wall space.
var walls: VanSideWall = null
var mid_y := 0.0
var half_w := 1.0
var half_h := 1.0
## Metres the middle of the opening is pushed toward -Z (the cabin).
var dent := 0.0
var segments := 14
## Called with each new MeshInstance3D before add_child (street-lit layers). May be invalid.
var on_mesh: Callable


func _init(p_walls: VanSideWall, p_mid_y: float, p_half_w: float, p_half_h: float) -> void:
	walls = p_walls
	mid_y = p_mid_y
	half_w = p_half_w
	half_h = p_half_h


## Local +Z of the wall profile (plus the dent) at local (x, y).
func surface_z(x: float, y: float) -> float:
	var curve := 0.0
	if walls != null:
		curve = walls.wall_x_at(mid_y + y) - walls.wall_x_at(mid_y)
	return curve - dent * _bump(x / half_w) * _bump(y / half_h)


func _bump(t: float) -> float:
	return 0.5 * (1.0 + cos(PI * clampf(t, -1.0, 1.0)))


## Orientation of the surface at (x, y): z along the normal, x kept as close to +X as it allows.
func basis_at(x: float, y: float) -> Basis:
	var e := 0.01
	var sx := (surface_z(x + e, y) - surface_z(x - e, y)) / (2.0 * e)
	var sy := (surface_z(x, y + e) - surface_z(x, y - e)) / (2.0 * e)
	var z_axis := Vector3(-sx, -sy, 1.0).normalized()
	var x_axis := (Vector3.RIGHT - z_axis * z_axis.dot(Vector3.RIGHT)).normalized()
	var y_axis := z_axis.cross(x_axis)
	return Basis(x_axis, y_axis, z_axis)


## A box standing on the surface at `at`, its back `z_back` off the surface along the normal.
func add_box(
	parent: Node3D, node_name: String, size: Vector3, at: Vector2, z_back: float, mat: Material
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	var b := basis_at(at.x, at.y)
	var pos := Vector3(at.x, at.y, surface_z(at.x, at.y)) + b.z * (z_back + size.z * 0.5)
	mi.transform = Transform3D(b, pos)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_commit(parent, mi)
	return mi


## One cone rivet head whose base sits `z_base` off the surface (1 mm sunk).
func add_rivet(
	parent: Node3D, node_name: String, at: Vector2, z_base: float, size: float, mat: Material
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = size * 0.5
	mesh.top_radius = RIVET_TOP_RADIUS
	mesh.height = RIVET_HEIGHT
	mesh.radial_segments = 8
	mesh.rings = 0
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	var b := basis_at(at.x, at.y) * Basis(Vector3.RIGHT, PI / 2.0)
	var pos := Vector3(at.x, at.y, surface_z(at.x, at.y))
	pos += basis_at(at.x, at.y).z * (z_base + RIVET_HEIGHT * 0.5 - 0.001)
	mi.transform = Transform3D(b, pos)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_commit(parent, mi)
	return mi


## One hex bolt head on the surface at `at`; z_base is its base height off the surface (2 mm sunk).
func add_bolt(
	parent: Node3D, node_name: String, at: Vector2, z_base: float, mat: Material
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = BOLT_RADIUS
	mesh.top_radius = BOLT_TOP_RADIUS
	mesh.height = BOLT_HEIGHT
	mesh.radial_segments = 6
	mesh.rings = 0
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	var sb := basis_at(at.x, at.y)
	# Turned about its own axis so the hex flats are not axis-aligned.
	var b := sb * Basis(Vector3.RIGHT, PI / 2.0) * Basis(Vector3.UP, 0.3)
	var pos := Vector3(at.x, at.y, surface_z(at.x, at.y))
	pos += sb.z * (z_base - BOLT_SINK + BOLT_HEIGHT * 0.5)
	mi.transform = Transform3D(b, pos)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_commit(parent, mi)
	return mi


## Eight points, counter-clockwise from +Z, of a rectangle with its corners cut by `chamfer`.
static func chamfered_rect(half_x: float, half_y: float, chamfer: float) -> PackedVector2Array:
	var hx := half_x
	var hy := half_y
	var c := chamfer
	return PackedVector2Array([
		Vector2(hx - c, -hy), Vector2(hx, -hy + c), Vector2(hx, hy - c), Vector2(hx - c, hy),
		Vector2(-hx + c, hy), Vector2(-hx, hy - c), Vector2(-hx, -hy + c), Vector2(-hx + c, -hy),
	])


## Prism of `poly` (counter-clockwise from +Z), z 0 to `depth`, its back `z_back` off the surface.
func add_prism(
	parent: Node3D, node_name: String, poly: PackedVector2Array, at: Vector2,
	z_back: float, depth: float, mat: Material
) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var n := poly.size()
	var centroid := Vector2.ZERO
	for p in poly:
		centroid += p
	centroid /= float(n)
	var cf := Vector3(centroid.x, centroid.y, depth)
	var cb := Vector3(centroid.x, centroid.y, 0.0)
	for i in range(n):
		var p0 := poly[i]
		var p1 := poly[(i + 1) % n]
		var f0 := Vector3(p0.x, p0.y, depth)
		var f1 := Vector3(p1.x, p1.y, depth)
		var b0 := Vector3(p0.x, p0.y, 0.0)
		var b1 := Vector3(p1.x, p1.y, 0.0)
		_add_tri(st, cf, f1, f0)
		_add_tri(st, cb, b0, b1)
		_add_tri(st, f0, f1, b1)
		_add_tri(st, f0, b1, b0)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = st.commit()
	var b := basis_at(at.x, at.y)
	var pos := Vector3(at.x, at.y, surface_z(at.x, at.y)) + b.z * z_back
	mi.transform = Transform3D(b, pos)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_commit(parent, mi)
	return mi


## Square tube `size` wide and deep, edges cut by `chamfer`, centred `z_center` off the surface.
func add_tube(
	parent: Node3D, node_name: String, vertical: bool, half_len: float, size: float,
	chamfer: float, z_center: float, mat: Material
) -> void:
	var h := size * 0.5
	var c := chamfer if chamfer < h else size * 0.25
	# Corners as (across, depth), in the rotational order of the old 4-point bars.
	var corners: Array[Vector2]
	if vertical:
		corners = [Vector2(h, -h), Vector2(-h, -h), Vector2(-h, h), Vector2(h, h)]
	else:
		corners = [Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]
	var section: Array[Vector2] = []
	for k in range(4):
		var corner := corners[k]
		var prev := corners[(k + 3) % 4]
		var next := corners[(k + 1) % 4]
		section.append(corner + (prev - corner).normalized() * c)
		section.append(corner + (next - corner).normalized() * c)
	var segs := maxi(segments, 2)
	var rings: Array = []
	for i in range(segs + 1):
		var along := lerpf(-half_len, half_len, float(i) / float(segs))
		var ring: Array = []
		for s in section:
			var x := s.x if vertical else along
			var y := along if vertical else s.x
			ring.append(Vector3(x, y, z_center + s.y + surface_z(x, y)))
		rings.append(ring)
	_commit_lofted_bar(parent, node_name, rings, mat)


func _commit(parent: Node3D, mi: MeshInstance3D) -> void:
	if on_mesh.is_valid():
		on_mesh.call(mi)
	parent.add_child(mi)


func _commit_lofted_bar(parent: Node3D, node_name: String, rings: Array, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var segs := rings.size() - 1
	var n: int = (rings[0] as Array).size()

	for i in range(segs):
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		# Each consecutive point pair is one face; the second half of the ring is the same
		# quad turned one corner, which keeps the 4-point bars' original quad order.
		for j in range(n):
			var k := (j + 1) % n
			if j < n >> 1:
				_add_quad(st, a[j], b[j], b[k], a[k])
			else:
				_add_quad(st, a[k], a[j], b[j], b[k])

	var start: Array = rings[0]
	var end: Array = rings[segs]
	for k in range(1, n - 2, 2):
		_add_quad(st, start[0], start[k], start[k + 1], start[k + 2])
		_add_quad(st, end[0], end[k + 2], end[k + 1], end[k])

	st.generate_normals()
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_commit(parent, mi)


func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(a)
	st.set_uv(Vector2(1.0, 0.0))
	st.add_vertex(b)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(c)


func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(a)
	st.set_uv(Vector2(1.0, 0.0))
	st.add_vertex(b)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(c)
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(a)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(c)
	st.set_uv(Vector2(0.0, 1.0))
	st.add_vertex(d)
