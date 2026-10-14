extends RefCounted

## Smoke step: rays along +x across the rear-right arch's deep face show whether the salvage corner
## piece meets it with no depth step (D53). Meshes are taken into Shell-local space.

const _Ramp := preload("res://scripts/van/rear_door_ramp.gd")
const _Surround := preload("res://scripts/van/rear_door_surround.gd")
const _Flange := preload("res://scripts/van/rear_door_flange.gd")
const _Press := preload("res://scripts/van/look/van_salvage_piece1_press.gd")
const _Wall := preload("res://scripts/van/look/van_salvage_piece1_wall.gd")
const _NEAR := 0.005
const _MAX_NORMAL_DEG := 10.0
## The ring band: z from z_deep - 0.30 to z_deep (the post's face ends at the fillet).
const _BAND_Z0 := 0.30
const _BAND_Z1 := 0.0
const _BAND_STEP := 0.03
const _Y_MIN := 0.1
const _Y_MAX := 3.2
const _Y_STEP := 0.1
const _Z_SPAN := 0.03
const _Z_STEP := 0.005
const _MAX_STEP := 0.005
const _START_X := 2.0

var driver: Node


func _init(owner: Node) -> void:
	driver = owner


## Fails the run on the worst depth step along any sampled row, else logs the max step.
func run() -> void:
	var rig := VanAnchors.rig(driver.get_tree())
	var shell := rig.get_node_or_null(^"Interior/Shell") as Node3D if rig != null else null
	var piece := shell.get_node_or_null(^"SalvagePiece1") if shell != null else null
	var doors := shell.get_node_or_null(^"RearWall") if shell != null else null
	var hinge := doors.get_node_or_null(^"RightHinge") as Node3D if doors != null else null
	var portal := doors.get_node_or_null(^"Portal") if doors != null else null
	if piece == null or hinge == null or portal == null:
		driver._fail("salvage seam: SalvagePiece1, RightHinge or Portal missing")
		return
	var to_shell := shell.global_transform.affine_inverse()
	var faces := PackedVector3Array()
	for m in piece.find_children("*", "MeshInstance3D", true, false):
		_append(faces, m as MeshInstance3D, to_shell)
	for m in portal.find_children("*", "MeshInstance3D", true, false):
		var n := String(m.name)
		if n.begins_with("RampLoft") or n.begins_with("DeepRing_R") or n.begins_with("Ledge"):
			_append(faces, m as MeshInstance3D, to_shell)
	var tri := TriangleMesh.new()
	if not tri.create_from_faces(faces):
		driver._fail("salvage seam: no faces to sample")
		return
	var z_deep: float = (doors.transform * hinge.position).z + _Ramp.z_deep_rel()
	var worst := 0.0
	var largest := 0.0
	var worst_y := 0.0
	var worst_z := 0.0
	var steps := int(round((_Y_MAX - _Y_MIN) / _Y_STEP))
	var zs := int(round(_Z_SPAN * 2.0 / _Z_STEP))
	for i in steps + 1:
		var y := _Y_MIN + i * _Y_STEP
		var prev := NAN
		var prev_missing := false
		for j in zs + 1:
			var z := z_deep - _Z_SPAN + j * _Z_STEP
			var hit := tri.intersect_ray(Vector3(_START_X, y, z), Vector3.RIGHT)
			var missing := hit.is_empty()
			var x: float = NAN if missing else (hit["position"] as Vector3).x
			if j > 0:
				var step := 0.0
				if missing != prev_missing:
					step = INF
				elif not missing:
					step = absf(x - prev)
				if step != INF:
					largest = maxf(largest, step)
				if step > _MAX_STEP and step > worst:
					worst = step
					worst_y = y
					worst_z = z
			prev = x
			prev_missing = missing
	if worst > _MAX_STEP:
		driver._fail("salvage seam: y %.1f z %.3f step %.3f" % [worst_y, worst_z, worst])
		return
	driver._log("salvage seam: max step %.3f" % largest)
	var wall_node := piece.get_node_or_null(^"WallPieces") as MeshInstance3D
	var ramp_node := portal.get_node_or_null(^"RampLoft") as MeshInstance3D
	if wall_node == null or ramp_node == null:
		driver._fail("salvage seam: WallPieces or RampLoft missing")
		return
	_check_normals(wall_node, ramp_node, to_shell)
	var wall_faces := PackedVector3Array()
	_append(wall_faces, wall_node, to_shell)
	var wall_tri := TriangleMesh.new()
	if not wall_tri.create_from_faces(wall_faces):
		driver._fail("salvage seam: no wall faces for the band")
		return
	_check_band(wall_tri, z_deep)


## Every wall vertex within 5 mm of a RampLoft vertex must share its normal to within 10 degrees.
func _check_normals(wall: MeshInstance3D, ramp: MeshInstance3D, to_shell: Transform3D) -> void:
	var rarr := ramp.mesh.surface_get_arrays(0)
	var rv: PackedVector3Array = rarr[Mesh.ARRAY_VERTEX]
	var rn: PackedVector3Array = rarr[Mesh.ARRAY_NORMAL]
	var rxf := to_shell * ramp.global_transform
	var grid := {}
	for i in rv.size():
		var p := rxf * rv[i]
		var key := Vector3i((p / _NEAR).floor())
		if not grid.has(key):
			grid[key] = []
		grid[key].append([p, (rxf.basis * rn[i]).normalized()])
	var warr := wall.mesh.surface_get_arrays(0)
	var wv: PackedVector3Array = warr[Mesh.ARRAY_VERTEX]
	var wn: PackedVector3Array = warr[Mesh.ARRAY_NORMAL]
	var wxf := to_shell * wall.global_transform
	var worst := 0.0
	var at := Vector3.ZERO
	var pairs := 0
	for i in wv.size():
		var p := wxf * wv[i]
		var base := Vector3i((p / _NEAR).floor())
		var best := _NEAR
		var best_n := Vector3.ZERO
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				for dz in range(-1, 2):
					for e: Array in grid.get(base + Vector3i(dx, dy, dz), []):
						var d := p.distance_to(e[0])
						if d <= best:
							best = d
							best_n = e[1]
		if best_n == Vector3.ZERO:
			continue
		pairs += 1
		var deg := rad_to_deg((wxf.basis * wn[i]).normalized().angle_to(best_n))
		if deg > worst:
			worst = deg
			at = p
	driver._log("salvage seam: max normal %.1f at y %.3f z %.3f (%d vertex pairs)" % [
			worst, at.y, at.z, pairs])
	if pairs == 0:
		driver._fail("salvage seam: no wall vertex within 5 mm of a RampLoft vertex")
	if worst > _MAX_NORMAL_DEG:
		driver._fail("salvage seam: normal %.1f deg at y %.3f z %.3f" % [worst, at.y, at.z])


## Rays along the arch section's outward normal at the head arc's points and at a few heights up the
## +x side, over z beside the ring: the corner piece's room face must sit on the arch section.
func _check_band(wall_tri: TriangleMesh, z_deep: float) -> void:
	var half := float(VanInteriorSize.REAR_DOOR_HALF)
	var top := float(VanInteriorSize.REAR_DOOR_TOP)
	var radius := float(_Flange.RADIUS_TOP)
	var open: PackedVector2Array = _Surround._opening(half, top, _Surround.RAMP_OUT)
	var centre := Vector2(half - radius, top - radius)
	var samples: Array[Vector2] = []
	for k in range(_Flange.ARC_STEPS + 2, open.size() - 1):
		samples.append(open[k])
	var arc_end := samples[samples.size() - 1]
	for i in int(floor((arc_end.y - 1.0) / 0.1 + 1e-6)) + 1:
		samples.append(Vector2(arc_end.x, 1.0 + i * 0.1))
	# The band is the flat sheet only: pressed crests and the pocket (with its bevel) are left out.
	var crest_end: float = _Press.crest_end(z_deep)
	var skip: Array[Rect2] = [_Press.KICK,
			Rect2(_Press.POST_LOW.position, Vector2(crest_end - _Press.POST_LOW.position.x,
			_Press.POST_LOW.size.y)),
			Rect2(_Press.POST_UP.position, Vector2(crest_end - _Press.POST_UP.position.x,
			_Press.POST_UP.size.y))]
	var bev := float(_Surround.BEVEL)
	var pocket_z1 := z_deep - _Surround.RAMP_OUT
	skip.append(Rect2(pocket_z1 - _Surround.POCKET_X1 - _Wall.SINK, _Surround.POCKET_Y0 - bev,
			_Surround.POCKET_X1 + _Wall.SINK + bev, _Surround.POCKET_Y1 - _Surround.POCKET_Y0 + 2.0 * bev))
	var worst := 0.0
	var at := Vector2.ZERO
	var at_z := 0.0
	var zs := int(round((_BAND_Z0 + _BAND_Z1) / _BAND_STEP))
	for s in samples:
		var dir := (s - centre).normalized() if s.y > centre.y else Vector2.RIGHT
		for j in zs + 1:
			var z := z_deep - _BAND_Z0 + j * _BAND_STEP
			var pressed := false
			for r in skip:
				pressed = pressed or r.has_point(Vector2(z, s.y))
			if pressed:
				continue
			var from := Vector3(s.x - dir.x * 0.4, s.y - dir.y * 0.4, z)
			var hit := wall_tri.intersect_ray(from, Vector3(dir.x, dir.y, 0.0))
			var off := INF
			if not hit.is_empty():
				off = absf(((hit["position"] as Vector3) - Vector3(s.x, s.y, z)).dot(
						Vector3(dir.x, dir.y, 0.0)))
			if off > worst:
				worst = off
				at = s
				at_z = z
	driver._log("salvage seam: band max off %.3f at y %.3f z %.3f" % [worst, at.y, at_z])
	if worst > _MAX_STEP:
		driver._fail("salvage seam: band off %.3f at y %.3f z %.3f" % [worst, at.y, at_z])


func _append(faces: PackedVector3Array, m: MeshInstance3D, to_shell: Transform3D) -> void:
	if m == null or m.mesh == null:
		return
	var xf := to_shell * m.global_transform
	for v in m.mesh.get_faces():
		faces.append(xf * v)
