extends RefCounted
## Mesh builder for IronCross: rods, boxes, bolts and weld blobs that follow the bowed side wall.

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


## Sweeps a round section along `path` (local x, y, z before the wall bow; each point is mapped to
## (x, y, z + surface_z(x, y))). `radii` has one radius per path point. `rib_step` > 0 adds rebar ribs.
func add_rod(
	parent: Node3D, part_name: String, path: PackedVector3Array, radii: PackedFloat32Array,
	sides: int, rib_step: float, mat: Material, closed: bool = false
) -> MeshInstance3D:
	if path.size() < 2 or radii.size() != path.size():
		push_warning("add_rod %s: need 2+ points and one radius per point" % part_name)
		return null
	var ring_sides := maxi(sides, 3)
	var clean_pts := PackedVector3Array()
	var clean_rad := PackedFloat32Array()
	for i in range(path.size()):
		if clean_pts.size() > 0 and clean_pts[clean_pts.size() - 1].is_equal_approx(path[i]):
			continue
		clean_pts.append(path[i])
		clean_rad.append(radii[i])
	if clean_pts.size() < 2:
		push_warning("add_rod %s: path has no length" % part_name)
		return null
	var dense := _densify_with_radii(clean_pts, clean_rad, rib_step * 0.5 if rib_step > 0.0 else 0.04)
	var pts: PackedVector3Array = dense[0]
	var rads: PackedFloat32Array = dense[1]
	var count := pts.size()
	for i in range(count):
		if rib_step > 0.0 and i > 0 and i < count - 2 and i % 2 == 1:
			rads[i] *= 1.14
		pts[i].z += surface_z(pts[i].x, pts[i].y)

	# Parallel-transport frames.
	var tangents: Array[Vector3] = []
	for i in range(count):
		var prev := i - 1
		var next := i + 1
		if closed:
			prev = (i - 1 + count) % count
			next = (i + 1) % count
		else:
			prev = maxi(prev, 0)
			next = mini(next, count - 1)
		tangents.append((pts[next] - pts[prev]).normalized())
	var normals: Array[Vector3] = []
	var n0 := tangents[0].cross(Vector3.UP)
	if n0.length() < 0.001:
		n0 = tangents[0].cross(Vector3.RIGHT)
	normals.append(n0.normalized())
	for i in range(1, count):
		var n := normals[i - 1] - tangents[i] * normals[i - 1].dot(tangents[i])
		normals.append(n.normalized())

	var rings: Array[PackedVector3Array] = []
	for i in range(count):
		var bin := tangents[i].cross(normals[i])
		var ring := PackedVector3Array()
		for j in range(ring_sides):
			var a := TAU * float(j) / float(ring_sides)
			ring.append(pts[i] + rads[i] * (cos(a) * normals[i] + sin(a) * bin))
		rings.append(ring)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var spans := count if closed else count - 1
	for i in range(spans):
		var ra := rings[i]
		var rb := rings[(i + 1) % count]
		for j in range(ring_sides):
			var k := (j + 1) % ring_sides
			_add_quad(st, ra[j], rb[j], rb[k], ra[k])
	if not closed:
		var start := rings[0]
		var end := rings[count - 1]
		for j in range(ring_sides):
			var k := (j + 1) % ring_sides
			_add_tri(st, pts[0], start[j], start[k])
			_add_tri(st, pts[count - 1], end[k], end[j])
	st.generate_normals()
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_commit(parent, mi)
	return mi


## A lumpy weld blob: a squashed low-poly ball at `center` (local, bow-mapped), `size` = full extents.
func add_blob(
	parent: Node3D, part_name: String, center: Vector3, size: Vector3,
	rng: RandomNumberGenerator, mat: Material
) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.radius = 0.5
	mesh.height = 1.0
	var mi := MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = mesh
	var jitter := Vector3(
		rng.randf_range(0.8, 1.2), rng.randf_range(0.8, 1.2), rng.randf_range(0.8, 1.2)
	)
	var b := basis_at(center.x, center.y) * Basis(Vector3.BACK, rng.randf_range(0.0, TAU))
	b = b.scaled_local(size * jitter)
	mi.transform = Transform3D(b, Vector3(center.x, center.y, center.z + surface_z(center.x, center.y)))
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_commit(parent, mi)
	return mi


## Points of a helix of `turns` turns around the segment a..b (local space), radius `r`,
## `steps_per_turn` points per turn, starting at angle `phase`.
static func helix_path(
	a: Vector3, b: Vector3, r: float, turns: float, steps_per_turn: int, phase: float
) -> PackedVector3Array:
	var d := b - a
	var uv := _perp_pair(d)
	var n := maxi(2, int(turns * steps_per_turn))
	var out := PackedVector3Array()
	for i in range(n + 1):
		var ang := phase + TAU * turns * float(i) / float(n)
		out.append(a + d * (float(i) / float(n)) + r * (cos(ang) * uv[0] + sin(ang) * uv[1]))
	return out


## A closed ring of `steps` points of radius `r` around `center`, in the plane normal to `axis`.
static func ring_path(center: Vector3, axis: Vector3, r: float, steps: int) -> PackedVector3Array:
	var uv := _perp_pair(axis)
	var out := PackedVector3Array()
	for i in range(steps):
		var ang := TAU * float(i) / float(steps)
		out.append(center + r * (cos(ang) * uv[0] + sin(ang) * uv[1]))
	return out


## Resamples `path` so no segment is longer than `max_len` (keeps every original point). Used so a
## long straight bar still bends with the wall bow and gets rib rings.
static func densify(path: PackedVector3Array, max_len: float) -> PackedVector3Array:
	var radii := PackedFloat32Array()
	radii.resize(path.size())
	var res := _densify_with_radii(path, radii, max_len)
	return res[0]


## Two unit vectors perpendicular to `axis` and to each other.
static func _perp_pair(axis: Vector3) -> Array[Vector3]:
	var dir := axis.normalized()
	var u := dir.cross(Vector3.UP)
	if u.length() < 0.001:
		u = dir.cross(Vector3.RIGHT)
	u = u.normalized()
	return [u, dir.cross(u)]


## `densify` that interpolates a radius per point too; returns [points, radii].
static func _densify_with_radii(
	path: PackedVector3Array, radii: PackedFloat32Array, max_len: float
) -> Array:
	var pts := PackedVector3Array()
	var rads := PackedFloat32Array()
	for i in range(path.size()):
		pts.append(path[i])
		rads.append(radii[i])
		if i == path.size() - 1:
			break
		var extra := int(ceil(path[i].distance_to(path[i + 1]) / max_len)) - 1
		for k in range(1, extra + 1):
			var f := float(k) / float(extra + 1)
			pts.append(path[i].lerp(path[i + 1], f))
			rads.append(lerpf(radii[i], radii[i + 1], f))
	return [pts, rads]


func _commit(parent: Node3D, mi: MeshInstance3D) -> void:
	if on_mesh.is_valid():
		on_mesh.call(mi)
	parent.add_child(mi)


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
