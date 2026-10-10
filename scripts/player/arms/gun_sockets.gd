class_name GunSockets
extends RefCounted
## Named attachment sockets on the railgun Body: Marker3Ds with size, normal, zone and used metas
## that boon visuals claim by zone preference. Positions never depend on rng.

const GROUP := &"gun_sockets"


## Creates every socket under `body`. Same arguments as RailgunBody.build: `p` the gun's palm
## length, `z_front` the guard's front z, `y_axis` the guard's top.
static func place(body: Node3D, p: float, z_front: float, y_axis: float) -> void:
	var ya := y_axis
	var zf := z_front
	var zt := zf - 2.8 * p
	var top := Vector3(0.45, 0.35, 0.45)
	var left := Vector3(0.30, 0.25, 0.5)
	var rear := Vector3(0.25, 0.3, 0.3)
	var under := Vector3(0.4, 0.3, 0.4)
	# Start points sit inside the mesh they belong to, so the snap lands them on its face: the
	# upper barrel's centre (top, muzzle), the lower barrel's centre (left, right, rear, under)
	# and the wedge's flank between the lower barrel's top and its slope (left_a).
	var uy := ya + RailgunBarrels.UP_Y * p
	var ly := ya + RailgunBarrels.LOW_Y * p
	var low_bottom := ly - (RailgunBarrels.LOW_R - 0.04) * p
	var wedge_front := zf - 0.15 * p
	var wedge_len := RailgunBody.WEDGE_ZR * p - wedge_front
	var wedge_y := ya + (RailgunBarrels.LOW_Y + RailgunBarrels.LOW_R + 0.10) * p
	var rows: Array = [
		["Socket_top_a", Vector3(0.0, uy, zt + 1.6 * p), top, Vector3.UP],
		["Socket_top_b", Vector3(0.0, uy, zt + 2.05 * p), top, Vector3.UP],
		["Socket_top_c", Vector3(0.0, uy, zt + 2.5 * p), top, Vector3.UP],
		["Socket_left_a", Vector3(-0.10 * p, wedge_y, wedge_front + 0.3 * wedge_len), left,
				Vector3.LEFT],
		["Socket_left_b", Vector3(-0.10 * p, ly, zf - 0.9 * p), left, Vector3.LEFT],
		["Socket_left_c", Vector3(-0.10 * p, ly, zf - 2.3 * p), left, Vector3.LEFT],
		["Socket_rear_a", Vector3(-0.08 * p, ly, 0.25 * p), rear, Vector3.BACK],
		["Socket_rear_b", Vector3(0.08 * p, ly, 0.25 * p), rear, Vector3.BACK],
		["Socket_muzzle_a", Vector3(0.0, uy, zt + 1.1 * p), Vector3(0.4, 0.3, 0.3),
				Vector3.UP],
		["Socket_muzzle_b", Vector3(-0.15 * p, uy, zt + 1.2 * p),
				Vector3(0.3, 0.4, 0.3), Vector3.LEFT],
		["Socket_under_a", Vector3(0.0, low_bottom, zf - 1.0 * p), under, Vector3.DOWN],
		["Socket_under_b", Vector3(0.0, low_bottom, zf - 2.0 * p), under, Vector3.DOWN],
		["Socket_hang_a", Vector3(-0.05 * p, low_bottom, zf - 0.4 * p), Vector3(0.3, 0.6, 0.3),
				Vector3.DOWN],
		["Socket_right_a", Vector3(0.10 * p, ly, zf - 1.2 * p), left, Vector3.RIGHT],
	]
	for row: Array in rows:
		var m := Marker3D.new()
		m.name = row[0] as String
		m.position = row[1] as Vector3
		m.set_meta(&"spec_pos", m.position)
		m.set_meta(&"size", (row[2] as Vector3) * p)
		m.set_meta(&"normal", row[3] as Vector3)
		m.set_meta(&"zone", StringName((row[0] as String).split("_")[1]))
		m.set_meta(&"used", false)
		body.add_child(m)
		m.add_to_group(GROUP)
	# Snap each socket out of the meshes it sits inside (the body is scaled over the hand, so the
	# spec offsets alone sit inside the parts). Geometry only, so deterministic. A snap over 0.6 p
	# keeps the spec position.
	var boxes := mesh_boxes(body)
	for m in all(body):
		var n: Vector3 = m.get_meta(&"normal")
		var ax := n.abs().max_axis_index()
		var sgn := signf(n[ax])
		var half := (m.get_meta(&"size") as Vector3)[ax] * 0.5
		var pos := m.position
		for _i in range(4):
			var ext := -INF
			for b in boxes:
				if b.grow(0.01 * p).has_point(pos):
					ext = maxf(ext, b.end[ax] if sgn > 0.0 else -b.position[ax])
			if ext == -INF:
				break
			pos[ax] = sgn * (ext + half + 0.02 * p)
		if pos.distance_to(m.position) < 0.6 * p:
			m.position = pos


## Every MeshInstance3D AABB under `body` in Body space, skipping the debug gizmos.
static func mesh_boxes(body: Node3D) -> Array[AABB]:
	var out: Array[AABB] = []
	var stack: Array[Node] = [body]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for c in node.get_children():
			if c.name == &"SocketGizmos":
				continue
			stack.append(c)
			if c is MeshInstance3D:
				var xf := Transform3D.IDENTITY
				var cur: Node = c
				while cur != body:
					xf = (cur as Node3D).transform * xf
					cur = cur.get_parent()
				out.append(xf * (c as MeshInstance3D).get_aabb())
	return out


## The boxes whose footprint across the two axes perpendicular to `normal` contains `point`.
static func footprint_boxes(boxes: Array[AABB], point: Vector3, normal: Vector3) -> Array[AABB]:
	var ax := normal.abs().max_axis_index()
	var out: Array[AABB] = []
	for b in boxes:
		var inside := true
		for i in range(3):
			if i != ax and (point[i] < b.position[i] or point[i] > b.end[i]):
				inside = false
		if inside:
			out.append(b)
	return out


## Every socket under `body`, in build order.
static func all(body: Node3D) -> Array[Marker3D]:
	var out: Array[Marker3D] = []
	for c in body.get_children():
		if c is Marker3D and c.has_meta(&"zone"):
			out.append(c as Marker3D)
	return out


## The first free socket of the earliest preferred zone; marks it used. Null when none is free.
static func claim(body: Node3D, zones: Array[StringName]) -> Marker3D:
	var sockets := all(body)
	for zone_id: StringName in zones:
		for s in sockets:
			if zone(s) == zone_id and not bool(s.get_meta(&"used", false)):
				s.set_meta(&"used", true)
				return s
	return null


## Frees a claimed socket.
static func release(socket: Marker3D) -> void:
	if socket != null:
		socket.set_meta(&"used", false)


## The socket's zone id (top, left, rear, muzzle, under, hang, right).
static func zone(socket: Marker3D) -> StringName:
	return socket.get_meta(&"zone", &"") as StringName
