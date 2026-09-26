extends RefCounted
## Routes power cables around machine keep-out boxes inside the bowed shell and builds the small
## clamp, junction box, tape, plug and coil parts that VanCableRuns hangs on them.

const FALLBACK_WALL_X := 2.3
const WALL_MARGIN := 0.10
const CEIL_MARGIN := 0.05
const AISLE_HALF_X := 0.6
const AISLE_TOP_Y := 2.2
const END_SKIP := 0.25
const DETOUR_X_STEP := 0.1
const DETOUR_X_MAX := 0.4
const DETOUR_Y := 0.3
const COIL_RADIUS := 0.12
const COIL_SEGMENTS := 6

var _walls: VanSideWall


func _init(walls: VanSideWall) -> void:
	_walls = walls


## Inner |x| of the bowed wall at height y, with a fallback when the wall node is missing.
func wall_x(y: float) -> float:
	if _walls == null:
		return FALLBACK_WALL_X
	return _walls.wall_x_at(y)


func ceiling_y(x: float) -> float:
	return 3.02 + 0.38 * (1.0 - pow(x / 2.36, 2.0)) - 0.015


## Inserts a detour vertex into every segment that crosses a keep-out box; gives up (returns the
## clamped originals) when neither a shift toward the aisle nor one upward clears both halves.
func route(points: PackedVector3Array, keepouts: Array[AABB]) -> PackedVector3Array:
	var out := PackedVector3Array()
	if points.is_empty():
		return out
	out.append(points[0])
	for i: int in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		if a.distance_to(b) >= 0.01 and _blocked(a, b, keepouts):
			var detour := _detour(a, b, keepouts)
			if detour.is_empty():
				return _clamped(points)
			out.append(detour[0])
		out.append(b)
	return _clamped(out)


## Splits each segment longer than 0.5 m at its middle and lowers that vertex by amount.
func sag(points: PackedVector3Array, amount: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i: int in range(points.size()):
		if i > 0 and points[i - 1].distance_to(points[i]) > 0.5:
			var mid: Vector3 = (points[i - 1] + points[i]) * 0.5
			mid.y -= amount
			out.append(mid)
		out.append(points[i])
	return out


## Ring clamp around a cable running along dir: box strap, round stand-off or thin zip tie.
func add_clamp(parent: Node3D, pos: Vector3, dir: Vector3, radius: float, style: int,
		steel: Material, tie: Material) -> void:
	var w := radius * 2.0 + 0.03
	match style % 3:
		0:
			_add(parent, _box(Vector3(w, w, 0.03)), steel, pos, _facing(dir))
		1:
			_add(parent, _cyl(radius + 0.016, 0.03), steel, pos, _facing(dir) * _axis_fix())
		_:
			_add(parent, _box(Vector3(w - 0.01, w - 0.01, 0.012)), tie, pos, _facing(dir))


## Steel cube where a route joins a trunk, with two terminal studs on its underside.
func add_junction_box(parent: Node3D, pos: Vector3, steel: Material, dark: Material) -> void:
	_add(parent, _box(Vector3(0.12, 0.12, 0.12)), steel, pos, Basis.IDENTITY)
	for sx: float in [-0.03, 0.03]:
		_add(parent, _cyl(0.012, 0.05), dark, pos + Vector3(sx, -0.085, 0.0), Basis.IDENTITY)


## Short band of tape around a cable; length 0.05 for a marker band, longer for a splice.
func add_tape_band(parent: Node3D, pos: Vector3, dir: Vector3, radius: float, mat: Material,
		length: float) -> void:
	var w := radius * 2.0 + 0.02
	_add(parent, _box(Vector3(w, w, length)), mat, pos, _facing(dir))


## Plug block seated on a machine port; the cable arrives along dir.
func add_plug(parent: Node3D, port: Vector3, dir: Vector3, mat: Material) -> void:
	_add(parent, _box(Vector3(0.08, 0.06, 0.05)), mat, port - dir.normalized() * 0.025, _facing(dir))


## Spare cable coil hanging from a wall hook; its ring lies flat against the wall (YZ plane).
func add_coil(parent: Node3D, center: Vector3, cable_mat: Material, hook_mat: Material) -> void:
	var ring := PackedVector3Array()
	for i: int in range(COIL_SEGMENTS + 1):
		var a := TAU * float(i) / float(COIL_SEGMENTS)
		ring.append(center + Vector3(0.0, sin(a) * COIL_RADIUS, cos(a) * COIL_RADIUS))
	MachineParts.cable_bundle(parent, ring, cable_mat, 0.014, 1)
	var wall_side := signf(center.x)
	var hook_pos := center + Vector3(wall_side * 0.035, COIL_RADIUS + 0.005, 0.0)
	_add(parent, _box(Vector3(0.07, 0.03, 0.03)), hook_mat, hook_pos, Basis.IDENTITY)


## Machine power ports in host-local space, keyed "machine_role" (e.g. "relay_rack_hub").
func read_ports(host: Node3D, group: StringName) -> Dictionary:
	var ports := {}
	for node in host.get_tree().get_nodes_in_group(group):
		var marker := node as Node3D
		if marker == null or not marker.has_meta(&"machine") or not marker.has_meta(&"role"):
			continue
		var key := "%s_%s" % [marker.get_meta(&"machine"), marker.get_meta(&"role")]
		ports[key] = host.to_local(marker.global_position)
	return ports


## Every machine's collision box in host space, grown 0.05 m, for route() to avoid.
func build_keepouts(props: Node, host: Node3D) -> Array[AABB]:
	var boxes: Array[AABB] = []
	if props == null:
		return boxes
	var to_rig := host.global_transform.affine_inverse()
	for body in props.get_children():
		if not (body is StaticBody3D):
			continue
		for child in body.get_children():
			var cs := child as CollisionShape3D
			if cs == null or not (cs.shape is BoxShape3D):
				continue
			var half := (cs.shape as BoxShape3D).size * 0.5
			var xf := to_rig * (body as StaticBody3D).global_transform * cs.transform
			var box := AABB(xf * half, Vector3.ZERO)
			for corner: int in range(8):
				var sign_v := Vector3(
					-1.0 if corner & 1 == 0 else 1.0,
					-1.0 if corner & 2 == 0 else 1.0,
					-1.0 if corner & 4 == 0 else 1.0)
				box = box.expand(xf * (half * sign_v))
			boxes.append(box.grow(0.05))
	return boxes


func _clamped(points: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p: Vector3 in points:
		out.append(_clamp_point(p))
	return out


func _clamp_point(p: Vector3) -> Vector3:
	var limit := wall_x(p.y) - WALL_MARGIN
	p.x = clampf(p.x, -limit, limit)
	p.y = minf(p.y, ceiling_y(p.x) - CEIL_MARGIN)
	return p


func _in_aisle(p: Vector3) -> bool:
	return absf(p.x) < AISLE_HALF_X and p.y < AISLE_TOP_Y


func _blocked(a: Vector3, b: Vector3, keepouts: Array[AABB]) -> bool:
	for box: AABB in keepouts:
		# An endpoint within 0.25 m of a box means that box is the port's own machine.
		var own := box.grow(END_SKIP)
		if own.has_point(a) or own.has_point(b):
			continue
		var hit: Variant = box.intersects_segment(a, b)
		if hit != null or box.has_point(a) or box.has_point(b):
			return true
	return false


func _detour(a: Vector3, b: Vector3, keepouts: Array[AABB]) -> PackedVector3Array:
	var mid := (a + b) * 0.5
	var toward := 1.0
	if mid.x > 0.0:
		toward = -1.0
	var options: Array[Vector3] = []
	var dx := DETOUR_X_STEP
	while dx <= DETOUR_X_MAX + 0.001:
		options.append(mid + Vector3(toward * dx, 0.0, 0.0))
		dx += DETOUR_X_STEP
	options.append(mid + Vector3(0.0, DETOUR_Y, 0.0))
	for option: Vector3 in options:
		var c := _clamp_point(option)
		if _in_aisle(c):
			continue
		if not _blocked(a, c, keepouts) and not _blocked(c, b, keepouts):
			return PackedVector3Array([c])
	return PackedVector3Array()


func _facing(dir: Vector3) -> Basis:
	var up := Vector3.UP
	if absf(dir.normalized().dot(Vector3.UP)) > 0.99:
		up = Vector3.RIGHT
	return Basis.looking_at(dir.normalized(), up)


## Turns a Y-axis cylinder so its axis lies along the facing basis' forward direction.
func _axis_fix() -> Basis:
	return Basis(Vector3.RIGHT, -PI / 2.0)


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _cyl(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	return mesh


func _add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, basis: Basis) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = Transform3D(basis, pos)
	mi.layers = 2
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
