extends RefCounted
## Physics-proxy gap checks on the closed van (vanfix spec 1-3 D3): open outer edges and
## see-through leaks, found by raycasting temporary ConcavePolygonShape3D proxies of every
## visible triangle. Stateful: build_proxies() must run first, the checks read what it built.

const AuditExempt := preload("res://tools/van_audit/van_audit_exempt.gd")
const AuditSeams := preload("res://tools/van_audit/van_audit_seams.gd")
const PROXY_LAYER :=1 << 19
const EDGE_WELD := 0.001
const EDGE_MIN_LEN := 0.05
const EDGE_TOUCH_RADIUS := 0.015
const LEAK_MARGIN := 0.05
const LEAK_STEP := 0.02
const LEAK_RANGE := 12.0

var _rig: Node3D
var _tris: RefCounted
var _node_idx_by_body: Dictionary = {}
var _body_id_by_node: Dictionary = {}
var _tri_idx_by_body: Dictionary = {}
var _rid_by_body: Dictionary = {}


## One StaticBody3D per node with triangles, holding its triangles as a ConcavePolygonShape3D,
## under a fresh "AuditProxies" node parented to rig with identity transform. Layer 20 only,
## mask 0: never collides with game bodies.
func build_proxies(tris: RefCounted, rig: Node3D) -> Node3D:
	_rig = rig
	_tris = tris
	var proxies := Node3D.new()
	proxies.name = "AuditProxies"
	rig.add_child(proxies)
	proxies.transform = Transform3D.IDENTITY

	var faces_by_node: Dictionary = {}
	var tri_order_by_node: Dictionary = {}
	for t in range(tris.count()):
		var idx: int = tris.owner_idx[t]
		var faces: PackedVector3Array = faces_by_node.get(idx, PackedVector3Array())
		faces.append(tris.a[t])
		faces.append(tris.b[t])
		faces.append(tris.c[t])
		faces_by_node[idx] = faces
		var order: PackedInt32Array = tri_order_by_node.get(idx, PackedInt32Array())
		order.append(t)
		tri_order_by_node[idx] = order

	for idx in faces_by_node.keys():
		var body := StaticBody3D.new()
		body.collision_layer = PROXY_LAYER
		body.collision_mask = 0
		proxies.add_child(body)
		var shape_node := CollisionShape3D.new()
		var concave := ConcavePolygonShape3D.new()
		concave.backface_collision = true
		concave.set_faces(faces_by_node[idx])
		shape_node.shape = concave
		body.add_child(shape_node)

		var body_id: int = body.get_instance_id()
		_node_idx_by_body[body_id] = idx
		_body_id_by_node[idx] = body_id
		_tri_idx_by_body[body_id] = tri_order_by_node[idx]
		_rid_by_body[body_id] = body.get_rid()

	return proxies


## First front-facing proxy hit along from->to (rig space), converted to world for the query.
## Back-facing hits are recorded and the ray restarts 0.002 m past them, at most 16 steps.
func first_visible_hit(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	var back_nodes: Array[String] = []
	var origin := from
	var dir := (to - from).normalized()
	var xform := _rig.global_transform

	for _step in range(16):
		var params := PhysicsRayQueryParameters3D.new()
		params.from = xform * origin
		params.to = xform * to
		params.collision_mask = PROXY_LAYER
		params.hit_back_faces = true
		params.hit_from_inside = false
		var hit: Dictionary = space.intersect_ray(params)
		if hit.is_empty():
			return {"back_nodes": back_nodes}

		var body_id: int = hit.collider_id
		var node_idx: int = int(_node_idx_by_body.get(body_id, -1))
		var node_path: String = _tris.paths[node_idx] if node_idx >= 0 else ""
		var face_index: int = int(hit.get("face_index", -1))
		var tri_normal: Vector3 = xform.basis.inverse() * (hit.normal as Vector3)
		if face_index >= 0 and _tri_idx_by_body.has(body_id):
			var tri_list: PackedInt32Array = _tri_idx_by_body[body_id]
			if face_index < tri_list.size():
				tri_normal = _tris.n[tri_list[face_index]]

		var pos_rig: Vector3 = xform.affine_inverse() * (hit.position as Vector3)
		var double_sided: bool = node_idx >= 0 and _tris.double_sided[node_idx] != 0
		if tri_normal.dot(dir) < 0.0 or double_sided:
			return {"pos": pos_rig, "node": node_path, "front": true, "back_nodes": back_nodes}

		back_nodes.append(node_path)
		origin = pos_rig + dir * 0.002

	return {"back_nodes": back_nodes}


## Every proxy hit along from->to (rig space), up to 8, restarting 0.002 m past each, as
## "<node path>:<F|B>@(x, y, z)" joined by " > ". Never stops at a front hit; locates leaks.
func trace_ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> String:
	var parts: Array[String] = []
	var origin := from
	var dir := (to - from).normalized()
	var xform := _rig.global_transform

	for _step in range(8):
		var params := PhysicsRayQueryParameters3D.new()
		params.from = xform * origin
		params.to = xform * to
		params.collision_mask = PROXY_LAYER
		params.hit_back_faces = true
		params.hit_from_inside = false
		var hit: Dictionary = space.intersect_ray(params)
		if hit.is_empty():
			break

		var body_id: int = hit.collider_id
		var node_idx: int = int(_node_idx_by_body.get(body_id, -1))
		var node_path: String = _tris.paths[node_idx] if node_idx >= 0 else "?"
		var face_index: int = int(hit.get("face_index", -1))
		var tri_normal: Vector3 = xform.basis.inverse() * (hit.normal as Vector3)
		if face_index >= 0 and _tri_idx_by_body.has(body_id):
			var tri_list: PackedInt32Array = _tri_idx_by_body[body_id]
			if face_index < tri_list.size():
				tri_normal = _tris.n[tri_list[face_index]]

		var pos_rig: Vector3 = xform.affine_inverse() * (hit.position as Vector3)
		var double_sided: bool = node_idx >= 0 and _tris.double_sided[node_idx] != 0
		var front: bool = tri_normal.dot(dir) < 0.0 or double_sided
		parts.append("%s:%s@(%.3f, %.3f, %.3f)" % [
			node_path, "F" if front else "B", pos_rig.x, pos_rig.y, pos_rig.z,
		])
		origin = pos_rig + dir * 0.002

	return " > ".join(parts)


## Open outer edges: exterior triangles (render layer 1) whose weld-1mm edge is used by exactly
## one triangle and doesn't meet another proxy body at 3 samples along its length.
func check_edges(tris: RefCounted, runner: Node) -> void:
	var started := Time.get_ticks_msec()
	var space: PhysicsDirectSpaceState3D = _rig.get_world_3d().direct_space_state

	var grid: Dictionary = tris.build_grid(0.25)
	var agg: Dictionary = {}
	for idx in range(tris.nodes.size()):
		if not (int(tris.layers[idx]) & 1):
			continue
		if not _body_id_by_node.has(idx):
			continue
		var own_rid: RID = _rid_by_body[_body_id_by_node[idx]]

		var vert_key: Dictionary = {}
		var vert_pos: Array[Vector3] = []
		var edge_uses: Dictionary = {}
		for t in range(tris.count()):
			if tris.owner_idx[t] != idx:
				continue
			var ia := _weld(tris.a[t], vert_key, vert_pos)
			var ib := _weld(tris.b[t], vert_key, vert_pos)
			var ic := _weld(tris.c[t], vert_key, vert_pos)
			_record_edge(edge_uses, ia, ib)
			_record_edge(edge_uses, ib, ic)
			_record_edge(edge_uses, ic, ia)

		var open_count := 0
		var longest: Dictionary = {}
		for key: Vector2i in edge_uses.keys():
			if int(edge_uses[key]) != 1:
				continue
			var p0: Vector3 = vert_pos[key.x]
			var p1: Vector3 = vert_pos[key.y]
			var length: float = p0.distance_to(p1)
			if length < EDGE_MIN_LEN:
				continue
			if _edge_meets_neighbour(space, own_rid, p0, p1):
				continue
			if AuditSeams.edge_meets_other_mesh(tris, grid, idx, p0, p1):
				continue
			if AuditSeams.edge_covered_by_collinear(tris, grid, p0, p1):
				continue
			open_count += 1
			if longest.is_empty() or length > float(longest.length):
				longest = {"length": length, "at": (p0 + p1) * 0.5}

		if open_count > 0:
			agg[idx] = {"open": open_count, "length": longest.length, "at": longest.at}

	var idx_list: Array = agg.keys()
	idx_list.sort_custom(func(x: int, y: int) -> bool: return float(agg[x].length) > float(agg[y].length))
	for idx: int in idx_list:
		var row: Dictionary = agg[idx]
		var at: Vector3 = row.at
		var path: String = tris.paths[idx]
		var rule: Dictionary = AuditExempt.rule_for("EDGE", path, "")
		var text := "node=%s open=%d length=%.3f at=(%.3f, %.3f, %.3f)" % [
			path, row.open, row.length, at.x, at.y, at.z,
		]
		if rule.is_empty():
			runner.add_finding("EDGE", text)
		else:
			runner.add_finding("EDGE_EXEMPT", text + " rule=%s" % rule.d)
	print("AUDIT edges (%d ms)" % (Time.get_ticks_msec() - started))


## from 8 cabin points, cast a Fibonacci sphere of rays; a leak is one with no front hit, or a
## front hit outside the body envelope. Blamed on the last surface seen through on the way.
func check_leaks_inside(_tris_unused: RefCounted, runner: Node, profile: VanBodyProfile) -> void:
	var started := Time.get_ticks_msec()
	var space: PhysicsDirectSpaceState3D = _rig.get_world_3d().direct_space_state
	var xform := _rig.global_transform
	var machine_mask: int = 0xFFFFFFFF & ~PROXY_LAYER

	var dirs := _fibonacci_sphere(1500)
	var agg: Dictionary = {}
	for y in [1.0, 1.7]:
		for z in [-3.5, -1.5, 0.5, 2.5]:
			var p := Vector3(0.0, y, z)
			var pt_params := PhysicsPointQueryParameters3D.new()
			pt_params.position = xform * p
			pt_params.collision_mask = machine_mask
			if not space.intersect_point(pt_params, 1).is_empty():
				continue

			for d in dirs:
				var hit: Dictionary = first_visible_hit(space, p, p + d * LEAK_RANGE)
				var leaking := not hit.has("pos")
				if hit.has("pos"):
					var pos: Vector3 = hit.pos
					leaking = (
						absf(pos.x) > profile.outer_x_at(pos.y) + LEAK_MARGIN
						or pos.y > profile.outer_roof_y_at(pos.x) + LEAK_MARGIN
						or pos.y < -0.4
					)
				if not leaking:
					continue

				var back_nodes: Array = hit.get("back_nodes", [])
				var through: String = String(back_nodes[-1]) if not back_nodes.is_empty() else "nothing"
				if agg.has(through):
					agg[through].rays = int(agg[through].rays) + 1
				else:
					agg[through] = {
						"through": through, "rays": 1, "at": _envelope_cross(p, d, profile),
						"from": p, "dir": d, "trace": trace_ray(space, p, p + d * LEAK_RANGE),
					}

	var rows: Array = agg.values()
	rows.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x.rays) > int(y.rays))
	for row: Dictionary in rows:
		var at: Vector3 = row.at
		var from: Vector3 = row.from
		var dir: Vector3 = row.dir
		runner.add_finding(
			"LEAK_IN",
			"through=%s rays=%d at=(%.3f, %.3f, %.3f) from=(%.3f, %.3f, %.3f) dir=(%.3f, %.3f, %.3f) trace=%s" % [
				row.through, row.rays, at.x, at.y, at.z,
				from.x, from.y, from.z, dir.x, dir.y, dir.z, row.trace,
			]
		)
	print("AUDIT leaks_inside (%d ms)" % (Time.get_ticks_msec() - started))


## 72 camera points on rings around the van, each casting rays at random points inside the
## triangle AABB; a leak is a first front hit on an interior-only node (VanInterior set, exterior
## clear).
func check_leaks_outside(tris: RefCounted, runner: Node) -> void:
	var started := Time.get_ticks_msec()
	var space: PhysicsDirectSpaceState3D = _rig.get_world_3d().direct_space_state

	var idx_by_path: Dictionary = {}
	for idx in range(tris.paths.size()):
		idx_by_path[tris.paths[idx]] = idx

	var box := AABB()
	var box_started := false
	for t in range(tris.count()):
		var tb: AABB = tris.tri_aabb(t)
		box = tb if not box_started else box.merge(tb)
		box_started = true
	var centre: Vector3 = box.get_center()

	var rng := RandomNumberGenerator.new()
	rng.seed = 1337

	var agg: Dictionary = {}
	for h in [0.8, 2.0, 4.5]:
		for az_i in range(24):
			var angle: float = TAU * float(az_i) / 24.0
			var origin := Vector3(centre.x + cos(angle) * 7.0, h, centre.z + sin(angle) * 7.0)
			for _r in range(400):
				var target := Vector3(
					box.position.x + rng.randf() * box.size.x,
					box.position.y + rng.randf() * box.size.y,
					box.position.z + rng.randf() * box.size.z,
				)
				var hit: Dictionary = first_visible_hit(space, origin, target)
				if not hit.has("pos"):
					continue
				var node_idx: int = int(idx_by_path.get(String(hit.node), -1))
				if node_idx < 0:
					continue
				var layer_bits: int = int(tris.layers[node_idx])
				if not (layer_bits & 2 and not (layer_bits & 1)):
					continue

				var back_nodes: Array = hit.get("back_nodes", [])
				var past: String = String(back_nodes[-1]) if not back_nodes.is_empty() else "none"
				var key: String = "%s|%s" % [String(hit.node), past]
				if agg.has(key):
					agg[key].rays = int(agg[key].rays) + 1
				else:
					agg[key] = {
						"sees": String(hit.node), "past": past, "rays": 1, "at": hit.pos,
						"from": origin, "dir": (target - origin).normalized(),
						"trace": trace_ray(space, origin, target),
					}

	var rows: Array = agg.values()
	rows.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x.rays) > int(y.rays))
	for row: Dictionary in rows:
		var at: Vector3 = row.at
		var from: Vector3 = row.from
		var dir: Vector3 = row.dir
		runner.add_finding(
			"LEAK_OUT",
			"sees=%s past=%s rays=%d at=(%.3f, %.3f, %.3f) from=(%.3f, %.3f, %.3f) dir=(%.3f, %.3f, %.3f) trace=%s" % [
				row.sees, row.past, row.rays, at.x, at.y, at.z,
				from.x, from.y, from.z, dir.x, dir.y, dir.z, row.trace,
			]
		)
	print("AUDIT leaks_outside (%d ms)" % (Time.get_ticks_msec() - started))


func _weld(p: Vector3, vert_key: Dictionary, vert_pos: Array[Vector3]) -> int:
	var key := Vector3i((p / EDGE_WELD).round())
	if vert_key.has(key):
		return int(vert_key[key])
	var vi: int = vert_pos.size()
	vert_pos.append(p)
	vert_key[key] = vi
	return vi


func _record_edge(edge_uses: Dictionary, i: int, j: int) -> void:
	var key := Vector2i(mini(i, j), maxi(i, j))
	edge_uses[key] = int(edge_uses.get(key, 0)) + 1


func _edge_meets_neighbour(space: PhysicsDirectSpaceState3D, own_rid: RID, p0: Vector3, p1: Vector3) -> bool:
	var xform := _rig.global_transform
	var shape := SphereShape3D.new()
	shape.radius = EDGE_TOUCH_RADIUS
	var exclude: Array[RID] = [own_rid]
	for tt in [0.25, 0.5, 0.75]:
		var p: Vector3 = p0.lerp(p1, tt)
		var params := PhysicsShapeQueryParameters3D.new()
		params.shape = shape
		params.transform = Transform3D(Basis(), xform * p)
		params.collision_mask = PROXY_LAYER
		params.exclude = exclude
		if space.intersect_shape(params, 4).is_empty():
			return false
	return true


func _envelope_cross(from: Vector3, dir: Vector3, profile: VanBodyProfile) -> Vector3:
	var steps: int = int(LEAK_RANGE / LEAK_STEP)
	for i in range(steps + 1):
		var p: Vector3 = from + dir * (float(i) * LEAK_STEP)
		if (
			absf(p.x) > profile.outer_x_at(p.y) + LEAK_MARGIN
			or p.y > profile.outer_roof_y_at(p.x) + LEAK_MARGIN
			or p.y < -0.4
		):
			return p
	return from + dir * LEAK_RANGE


func _fibonacci_sphere(n: int) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	var golden := PI * (3.0 - sqrt(5.0))
	for i in range(n):
		var y: float = 1.0 - (float(i) / float(n - 1)) * 2.0
		var radius: float = sqrt(maxf(0.0, 1.0 - y * y))
		var theta: float = golden * float(i)
		pts.append(Vector3(cos(theta) * radius, y, sin(theta) * radius))
	return pts
