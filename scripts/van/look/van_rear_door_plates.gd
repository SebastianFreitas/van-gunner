extends RefCounted
## Seeded scrap plates (welded or bolted, some dented or torn) on the cabin face of one rear leaf.

const _LeafBuild := preload("res://scripts/van/rear_door_leaf_build.gd")

## Leaf cabin face in hinge-local z; plates stand at z < this, like the hardware.
const FACE_Z := -0.08
const PLATE_T := 0.016
## The right leaf reads a shallow back as same-facing as its body face, so plates sink deeper.
const SINK := 0.02
## Plate front faces stand 1.4 cm proud of the leaf, backs 2 mm inside it.
const PROUD := 0.014
const BEAD_W := 0.018
const BEAD_H := 0.012
const BOLT_H := 0.008
const MARGIN := 0.03
const SEAM_X := VanInteriorSize.BOTTOM_HALF - 0.08
const HINGE_X := 0.04
const _WINDOW_HALF_W := 1.095
const WINDOW := Rect2(_LeafBuild.WINDOW_X - _WINDOW_HALF_W, -0.65, 2.19, 1.75)
const LOWER_ZONE := Rect2(0.40, -1.48, SEAM_X - 0.29 - 0.40, 0.78)
const UPPER_ZONE := Rect2(0.40, 1.14, SEAM_X - 0.24 - 0.40, 0.22)
const PALETTE: Array[Color] = [
	Color(0.10, 0.11, 0.095), Color(0.085, 0.07, 0.055),
	Color(0.12, 0.06, 0.045), Color(0.22, 0.22, 0.21),
]
const BEAD_COLOR := Color(0.06, 0.055, 0.05)


## Rolls 1-3 plates for the lower panel and maybe one strip above the window, builds them under
## `parent` (`mirror` -1 for the right leaf) and returns every node it added. `keep_out` is in
## left-leaf coordinates; only x and y are read.
static func build(parent: Node3D, mirror: float, rng: RandomNumberGenerator,
		keep_out: Array[AABB]) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var blocked: Array[Rect2] = [WINDOW]
	for box: AABB in keep_out:
		blocked.append(Rect2(box.position.x, box.position.y, box.size.x, box.size.y))
	var placed: Array[Rect2] = []
	var plate_count := rng.randi_range(1, 3)
	for i: int in range(plate_count):
		var size := Vector2(rng.randf_range(0.22, 0.60), rng.randf_range(0.16, 0.42))
		_try_plate(parent, mirror, rng, LOWER_ZONE, size, blocked, placed, out)
	if rng.randf() < 0.4:
		var strip := Vector2(rng.randf_range(0.5, 1.1), rng.randf_range(0.10, 0.16))
		_try_plate(parent, mirror, rng, UPPER_ZONE, strip, blocked, placed, out)
	return out


static func _try_plate(parent: Node3D, mirror: float, rng: RandomNumberGenerator, zone: Rect2,
		size: Vector2, blocked: Array[Rect2], placed: Array[Rect2], out: Array[Node3D]) -> void:
	var angle := deg_to_rad(rng.randf_range(-4.0, 4.0))
	var color := PALETTE[rng.randi_range(0, PALETTE.size() - 1)]
	var roughness := rng.randf_range(0.82, 0.9)
	var metallic := rng.randf_range(0.15, 0.28)
	var range_x := zone.size.x - size.x - 2.0 * MARGIN
	var range_y := zone.size.y - size.y - 2.0 * MARGIN
	if range_x < 0.0 or range_y < 0.0:
		return
	for attempt: int in range(12):
		var center := Vector2(
				zone.position.x + MARGIN + size.x * 0.5 + rng.randf() * range_x,
				zone.position.y + MARGIN + size.y * 0.5 + rng.randf() * range_y)
		var rect := Rect2(center - size * 0.5, size).grow(MARGIN)
		if rect.end.x > SEAM_X or rect.position.x < HINGE_X:
			continue
		var clear := true
		for other: Rect2 in blocked:
			if rect.intersects(other):
				clear = false
		for other: Rect2 in placed:
			if rect.intersects(other):
				clear = false
		if not clear:
			continue
		placed.append(rect)
		_build_plate(parent, mirror, rng, center, size, angle, color, roughness, metallic, out)
		return


static func _build_plate(parent: Node3D, mirror: float, rng: RandomNumberGenerator,
		center: Vector2, size: Vector2, angle: float, color: Color, roughness: float,
		metallic: float, out: Array[Node3D]) -> void:
	var pivot := Node3D.new()
	pivot.position = Vector3(mirror * center.x, center.y, 0.0)
	pivot.rotation = Vector3(0.0, 0.0, mirror * angle)
	parent.add_child(pivot)
	out.append(pivot)

	var mat := MachineParts.dark(color, roughness)
	mat.metallic = metallic
	var front_z := FACE_Z - PROUD
	_add(pivot, _box(Vector3(size.x, size.y, PLATE_T + SINK)), mat,
			Vector3(0.0, 0.0, front_z + (PLATE_T + SINK) * 0.5), Vector3.ZERO, out)

	var welded := rng.randf() < 0.5
	var damaged := rng.randf() < 0.3
	var dent := rng.randf() < 0.5
	if welded:
		_beads(pivot, rng, size, front_z, out)
	else:
		var bolt_mat := MachineParts.dark(color.darkened(0.3), roughness)
		for sx: float in [-1.0, 1.0]:
			for sy: float in [-1.0, 1.0]:
				var bolt := CylinderMesh.new()
				bolt.top_radius = 0.013
				bolt.bottom_radius = 0.013
				bolt.height = BOLT_H
				bolt.radial_segments = 6
				bolt.rings = 1
				_add(pivot, bolt, bolt_mat, Vector3(sx * (size.x * 0.5 - 0.03),
						sy * (size.y * 0.5 - 0.03), front_z - BOLT_H * 0.5 + 0.002),
						Vector3(PI * 0.5, 0.0, 0.0), out)
	if not damaged:
		return
	var dark_mat := MachineParts.dark(color.darkened(0.45), 0.9)
	if dent:
		# Centred, clear of the corner bolts and the edge beads.
		var cyl := CylinderMesh.new()
		cyl.top_radius = rng.randf_range(0.02, 0.035)
		cyl.bottom_radius = cyl.top_radius
		cyl.height = 0.008
		cyl.radial_segments = 8
		cyl.rings = 1
		_add(pivot, cyl, dark_mat, Vector3(0.0, 0.0, front_z),
				Vector3(PI * 0.5, 0.0, 0.0), out)
	else:
		# Stands 2.5 cm proud so it clears the beads and bolts by more than 1 cm.
		var sx := 1.0 if rng.randf() < 0.5 else -1.0
		var sy := 1.0 if rng.randf() < 0.5 else -1.0
		_add(pivot, _box(Vector3(0.07, 0.07, 0.03)), dark_mat,
				Vector3(sx * size.x * 0.5, sy * size.y * 0.5, front_z - 0.01),
				Vector3(0.0, 0.0, deg_to_rad(45.0)), out)


## Two or three edges, each with 2-4 short bead pieces, ends pulled 2.5 cm in so the pieces of
## neighbouring edges never share a corner plane.
static func _beads(pivot: Node3D, rng: RandomNumberGenerator, size: Vector2, front_z: float,
		out: Array[Node3D]) -> void:
	var mat := MachineParts.dark(BEAD_COLOR, 0.92)
	var edges: Array[int] = [0, 1, 2, 3]
	var edge_count := rng.randi_range(2, 3)
	for i: int in range(edge_count):
		var pick := rng.randi_range(i, 3)
		var edge := edges[pick]
		edges[pick] = edges[i]
		edges[i] = edge
		var horizontal := edge < 2
		var side := 1.0 if edge % 2 == 0 else -1.0
		var run := (size.x if horizontal else size.y) - 0.05
		var pieces := rng.randi_range(2, 4)
		var slot := run / float(pieces)
		for p: int in range(pieces):
			var length := slot * rng.randf_range(0.4, 0.85)
			var along := -run * 0.5 + slot * float(p) + rng.randf() * (slot - length) + length * 0.5
			var across := side * ((size.y if horizontal else size.x) * 0.5 - 0.012)
			var bead_size := Vector3(length, BEAD_W, BEAD_H + 0.004)
			var pos := Vector3(along, across, front_z - BEAD_H * 0.5 + 0.002)
			if not horizontal:
				bead_size = Vector3(BEAD_W, length, BEAD_H + 0.004)
				pos = Vector3(across, along, pos.z)
			_add(pivot, _box(bead_size), mat, pos, Vector3.ZERO, out)


static func _add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3,
		out: Array[Node3D]) -> void:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	inst.layers = 2
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.position = pos
	inst.rotation = rot
	parent.add_child(inst)
	out.append(inst)


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh
