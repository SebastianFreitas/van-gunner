extends RefCounted
## See-through leak checks over the gap proxies: cabin rays that escape, street rays that land
## on interior-only faces.

const AuditExempt := preload("res://tools/van_audit/van_audit_exempt.gd")
## Same physics layer van_audit_gaps.gd puts its proxies on.
const PROXY_LAYER := 1 << 19
const LEAK_MARGIN := 0.05
const LEAK_STEP := 0.02
const LEAK_RANGE := 12.0
## Growth of a closed door leaf / window sash box: x reaches the jamb lip and wall reveals
## inboard of the leaf, y the 13 cm leaf clearance plus 2 cm, z also the door's front post to the cab.
const OPENING_PAD := Vector3(0.40, 0.15, 0.20)

var _gaps: RefCounted
var _rig: Node3D


func _init(gaps: RefCounted, rig: Node3D) -> void:
	_gaps = gaps
	_rig = rig


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
				var hit: Dictionary = _gaps.first_visible_hit(space, p, p + d * LEAK_RANGE)
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
						"from": p, "dir": d,
						"trace": _gaps.trace_ray(space, p, p + d * LEAK_RANGE),
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
## clear). Hits on faces D54 exempts, inside a side opening's box (or the rule's own box), go to LEAK_OUT_EXEMPT.
func check_leaks_outside(tris: RefCounted, runner: Node, opening_boxes: Dictionary) -> void:
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
	var exempt_agg: Dictionary = {}
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
				var hit: Dictionary = _gaps.first_visible_hit(space, origin, target)
				if not hit.has("pos"):
					continue
				var node_idx: int = int(idx_by_path.get(String(hit.node), -1))
				if node_idx < 0:
					continue
				var layer_bits: int = int(tris.layers[node_idx])
				if not (layer_bits & 2 and not (layer_bits & 1)):
					continue

				var rule: Dictionary = AuditExempt.rule_for("LEAK_OUT", String(hit.node), "")
				var target_agg: Dictionary = agg
				var inside := false
				if rule.has("box"):
					inside = (rule.box as AABB).has_point(hit.pos)
				else:
					inside = _in_opening(hit.pos, opening_boxes)
				if not rule.is_empty() and inside:
					target_agg = exempt_agg
				var back_nodes: Array = hit.get("back_nodes", [])
				var past: String = String(back_nodes[-1]) if not back_nodes.is_empty() else "none"
				var key: String = "%s|%s" % [String(hit.node), past]
				if target_agg.has(key):
					target_agg[key].rays = int(target_agg[key].rays) + 1
				else:
					target_agg[key] = {
						"sees": String(hit.node), "past": past, "rays": 1, "at": hit.pos,
						"from": origin, "dir": (target - origin).normalized(),
						"trace": _gaps.trace_ray(space, origin, target),
					}
					if target_agg == exempt_agg:
						target_agg[key]["d"] = rule.d

	_emit_rows(runner, "LEAK_OUT", agg)
	_emit_rows(runner, "LEAK_OUT_EXEMPT", exempt_agg)
	print("AUDIT leaks_outside (%d ms)" % (Time.get_ticks_msec() - started))


func _emit_rows(runner: Node, section: String, agg: Dictionary) -> void:
	var rows: Array = agg.values()
	rows.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x.rays) > int(y.rays))
	for row: Dictionary in rows:
		var at: Vector3 = row.at
		var from: Vector3 = row.from
		var dir: Vector3 = row.dir
		var text := (
			"sees=%s past=%s rays=%d at=(%.3f, %.3f, %.3f) from=(%.3f, %.3f, %.3f) dir=(%.3f, %.3f, %.3f) trace=%s" % [
				row.sees, row.past, row.rays, at.x, at.y, at.z,
				from.x, from.y, from.z, dir.x, dir.y, dir.z, row.trace,
			]
		)
		if row.has("d"):
			text += " rule=%s" % row.d
		runner.add_finding(section, text)


func _in_opening(p: Vector3, boxes: Dictionary) -> bool:
	for label in boxes:
		var b: AABB = boxes[label]
		var grown := AABB(b.position - OPENING_PAD, b.size + OPENING_PAD * 2.0)
		if grown.has_point(p):
			return true
	return false


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
