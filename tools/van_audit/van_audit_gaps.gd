extends RefCounted
## Physics-proxy gap checks on the closed van (vanfix spec 1-3 D3): open outer edges, found by
## raycasting temporary ConcavePolygonShape3D proxies of every visible triangle. Stateful:
## build_proxies() must run first, the checks read what it built. The see-through leak checks
## live in van_audit_leaks.gd and query these proxies through first_visible_hit / trace_ray.

const AuditExempt := preload("res://tools/van_audit/van_audit_exempt.gd")
const AuditSeams := preload("res://tools/van_audit/van_audit_seams.gd")
const PROXY_LAYER :=1 << 19
const EDGE_WELD := 0.001
const EDGE_MIN_LEN := 0.05
const EDGE_TOUCH_RADIUS := 0.015

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
