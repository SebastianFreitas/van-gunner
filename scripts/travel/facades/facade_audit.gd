extends RefCounted
## Shared keep-out audits for a corridor tile's built facades: the bay-mouth clearance check
## (nothing built in front of a stop-bay opening) and the raider-lane clearance check (nothing
## built in the road below y=6). The smoke test and the `facade` debug console commands both
## call these so the two never drift apart.


const _FacadeKeepOut := preload("res://scripts/travel/facades/facade_keep_out.gd")
const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")
const _FacadeAuditInfill := preload("res://scripts/travel/facades/facade_audit_infill.gd")
const _FacadeAuditGround := preload("res://scripts/travel/facades/facade_audit_ground.gd")

const _FacadeAuditFixtures := preload("res://scripts/travel/facades/facade_audit_fixtures.gd")

const OPENING_BAY := 2
## A light's own AABB is its illumination range, not solid matter: it's tested as this small cube
## at its origin instead, so a fixture whose range sphere merely reaches a keep-out box doesn't
## fail, but one whose actual position sits inside one still does.
const _LIGHT_POINT_SIZE := Vector3(0.2, 0.2, 0.2)


## Every mouth violation on every tile under `corridor_root` that has an open bay side.
static func mouth_violations(corridor_root: Node) -> Array[String]:
	var violations: Array[String] = []
	var counts := {&"bays": 0, &"checked": 0}
	for piece in corridor_root.get_children():
		if not (piece is Node3D) or not piece.has_method(&"opening_of"):
			continue
		violations.append_array(tile_mouth_violations(piece as Node3D, counts))
	return violations


## Mouth violations for one tile's open bay side(s). Adds to `counts[&"bays"]` and
## `counts[&"checked"]` so a caller walking many tiles can still report one clear/fail line. A
## bay side that checked zero nodes is itself a violation: a hidden or half-freed build must not
## pass just because nothing was there to look at.
static func tile_mouth_violations(tile: Node3D, counts: Dictionary) -> Array[String]:
	var violations: Array[String] = []
	for side in [&"left", &"right"]:
		if tile.opening_of(side) != OPENING_BAY:
			continue
		counts[&"bays"] = int(counts.get(&"bays", 0)) + 1
		var side_sign := 1.0 if side == &"right" else -1.0
		var root: Node3D = tile.facade_root(side)
		if root == null:
			violations.append("bay side %s of %s has no facade root" % [side, tile.name])
			continue
		var body_boxes: Array[AABB] = _FacadeKeepOut.body_boxes_for(side_sign, OPENING_BAY)
		var prop_boxes: Array[AABB] = _FacadeKeepOut.prop_boxes_for(side_sign, OPENING_BAY)
		var inv: Transform3D = tile.global_transform.affine_inverse()
		var side_checked := 0
		for node in root.find_children("*", "VisualInstance3D", true, false):
			if not _is_visible_under(node, tile) or _is_being_freed(node, tile):
				continue
			var local_aabb: AABB = _tile_local_aabb(node, inv)
			var boxes := body_boxes if String(node.name).begins_with("Body") else prop_boxes
			for box in boxes:
				if box.intersects(local_aabb):
					violations.append(
						"facade node %s (aabb %s) covers the %s bay mouth" % [
							node.get_path(), local_aabb, side
						]
					)
			side_checked += 1
		counts[&"checked"] = int(counts.get(&"checked", 0)) + side_checked
		if side_checked == 0:
			violations.append("bay side %s of %s checked zero facade nodes" % [side, tile.name])
	return violations


## Recess sanity for both sides of one tile: the ground runs tile z -10..10 without gap or
## overlap, a bay side stays flat, every step-back is a quarter metre in 0..RECESS_MAX, a plaza
## is a whole metre, and joined lots agree. Also that no body or ruin shell sits in front of its
## lot's face, gap infill behind its gap's face, and that each recessed end lot has its pier. Adds the side's lots to `counts[&"lots"]` and its
## stepped-back lots to `counts[&"recess_lots"]`.
static func tile_recess_violations(tile: Node3D, counts: Dictionary) -> Array[String]:
	var violations: Array[String] = []
	for side in [&"left", &"right"]:
		var plans: Array = tile.facade_plans(side)
		var runs: Array[Vector4] = _FacadePlan.ground_runs(plans)
		var where := "tile %s side %s" % [tile.name, side]
		if runs.is_empty():
			violations.append("%s has no ground runs" % where)
		else:
			if absf(runs[0].x + 10.0) > 0.001 or absf(runs[-1].y - 10.0) > 0.001:
				violations.append(
					"%s ground runs span %.3f..%.3f, not -10..10" % [where, runs[0].x, runs[-1].y]
				)
			for i in runs.size():
				if runs[i].y <= runs[i].x:
					violations.append("%s run %d is empty: %s" % [where, i, runs[i]])
				if i > 0 and absf(runs[i].x - runs[i - 1].y) > 0.001:
					violations.append(
						"%s runs %d and %d gap or overlap: %.3f vs %.3f" % [
							where, i - 1, i, runs[i - 1].y, runs[i].x
						]
					)
		if tile.opening_of(side) == OPENING_BAY and not (runs.size() == 1 and runs[0].z == 0.0):
			violations.append("%s is a bay side with recessed ground runs %s" % [where, runs])
		violations.append_array(_side_mesh_violations(tile, side, plans, where))
		violations.append_array(_FacadeAuditInfill.violations(tile, side, plans, where))
		violations.append_array(_FacadeAuditGround.violations(tile, side, plans, where))
		violations.append_array(_FacadeAuditFixtures.violations(tile, side, plans, where))
		violations.append_array(_walk_detail_violations(tile, 0 if side == &"left" else 1, where))
		violations.append_array(_wall_collision_violations(tile, side, runs, where))
		var recess_lots := 0
		for i in plans.size():
			var plan: Dictionary = plans[i]
			var r := float(plan.get(&"recess", 0.0))
			if r < 0.0 or r > _FacadePlan.RECESS_MAX or absf(r * 4.0 - roundf(r * 4.0)) > 0.001:
				violations.append("%s lot %d recess %.3f is out of range or not a quarter" % [
					where, i, r
				])
			if bool(plan.get(&"plaza", false)) and absf(r - roundf(r)) > 0.001:
				violations.append("%s lot %d is a plaza with recess %.3f" % [where, i, r])
			if i > 0 and bool(plan.get(&"joined", false)):
				var prev: Dictionary = plans[i - 1]
				if (
					float(prev.get(&"recess", 0.0)) != r
					or bool(prev.get(&"plaza", false)) != bool(plan.get(&"plaza", false))
				):
					violations.append("%s lot %d is joined but differs from lot %d" % [
						where, i, i - 1
					])
			if r > 0.0:
				recess_lots += 1
		counts[&"lots"] = int(counts.get(&"lots", 0)) + plans.size()
		counts[&"recess_lots"] = int(counts.get(&"recess_lots", 0)) + recess_lots
	violations.append_array(_FacadeAuditFixtures.overhead_violations(
		tile, tile.facade_plans(&"left"), tile.facade_plans(&"right"), "tile %s" % tile.name, counts
	))
	return violations


## Wall collision follows the ground runs: a recessed closed side has one RunWalls box per run,
## step and recessed end, and the tscn wall box is on only for a closed side with one flat run.
static func _wall_collision_violations(
	tile: Node3D, side: StringName, runs: Array[Vector4], where: String
) -> Array[String]:
	var violations: Array[String] = []
	var left := side == &"left"
	var open: bool = tile.opening_of(side) != 0
	var expected := 0
	if not open and not (runs.size() == 1 and runs[0].z == 0.0):
		expected = runs.size()
		for i in range(1, runs.size()):
			if absf(runs[i - 1].z - runs[i].z) > 0.001:
				expected += 1
		if not runs.is_empty():
			if runs[0].z > 0.0:
				expected += 1
			if runs[-1].z > 0.0:
				expected += 1
	var body := tile.get_node_or_null(NodePath("RunWallsLeft" if left else "RunWallsRight"))
	var got := 0
	if body != null:
		for child in body.get_children():
			if child is CollisionShape3D:
				got += 1
	if got != expected:
		violations.append("%s has %d run wall boxes, expected %d" % [where, got, expected])
	var box := tile.get_node_or_null(
		NodePath("Surfaces/LeftWallCollision" if left else "Surfaces/RightWallCollision")
	) as CollisionShape3D
	if box != null:
		var want_on: bool = not open and expected == 0
		if box.disabled == want_on:
			violations.append("%s tscn wall box %s, expected %s" % [
				where, "off" if box.disabled else "on", "on" if want_on else "off"
			])
	return violations


## Sidewalk details follow the ground runs: the kerb-return count matches the run boundaries
## where the kerb moves, and utility boxes and bollards sit near their run's line.
static func _walk_detail_violations(
	tile: Node3D, side_idx: int, where: String
) -> Array[String]:
	var violations: Array[String] = []
	var road := tile.get_node_or_null(^"RoadFloor") as RoadFloor
	if road == null or not [road.sidewalk_left, road.sidewalk_right][side_idx]:
		return violations
	var runs: Array = road.ground_runs[side_idx]
	var meta_name := StringName("kerb_returns_%d" % side_idx)
	if road.has_meta(meta_name):
		var expected := 0
		for i in range(1, runs.size()):
			var a: Vector4 = runs[i - 1]
			var b: Vector4 = runs[i]
			var ka: float = a.z if int(a.w) == 0 else 0.0
			var kb: float = b.z if int(b.w) == 0 else 0.0
			if absf(ka - kb) > 0.01:
				expected += 1
		var got := int(road.get_meta(meta_name))
		if got != expected:
			violations.append("%s: kerb_returns %d, expected %d" % [where, got, expected])
	var suffix := "_L" if side_idx == 0 else "_R"
	for child in road.get_children():
		var n := String(child.name)
		var is_box := n.begins_with("UtilityBox_")
		var is_bollard := n.begins_with("Bollard_")
		if not (is_box or is_bollard) or not n.ends_with(suffix):
			continue
		var node := child as Node3D
		if node == null:
			continue
		var v: Vector4 = road.run_at(side_idx, node.position.z)
		var line: float
		if is_box:
			line = road.span_x * 0.5 - 0.35 + v.z
		else:
			var kerb_r: float = v.z if int(v.w) == 0 else 0.0
			line = road.span_x * 0.5 - road.sidewalk_width + 0.28 + kerb_r
		if absf(absf(node.position.x) - line) > 0.6:
			violations.append("%s: %s at x %.2f, line %.2f" % [where, n, node.position.x, line])
	return violations


## Built-mesh checks for one side of a tile: every body and ruin shell stays behind its lot's
## face, and the tile-end piers exist exactly for the recessed end lots. Skips a mouth side.
static func _side_mesh_violations(
	tile: Node3D, side: StringName, plans: Array, where: String
) -> Array[String]:
	var violations: Array[String] = []
	if plans.is_empty() or bool((plans[0] as Dictionary).get(&"mouth", false)):
		return violations
	var root := tile.get_node_or_null("Facades/Left" if side == &"left" else "Facades/Right")
	if root == null:
		return violations
	var side_sign := -1.0 if side == &"left" else 1.0
	for i in plans.size():
		var plan: Dictionary = plans[i]
		if bool(plan.get(&"mouth", false)):
			continue
		for body_name in ["Body%d" % i, "Body%dShell" % i]:
			var mi := root.get_node_or_null(body_name) as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			var aabb: AABB = mi.transform * mi.mesh.get_aabb()
			var near := minf(absf(aabb.position.x), absf(aabb.end.x))
			var face := absf(_FacadePlan.face_x(plan, side_sign))
			if near < face - 0.05:
				violations.append("%s %s reaches x %.3f, in front of its face %.3f" % [
					where, body_name, near, face
				])
	var expected: Array[String] = []
	var last := plans.size() - 1
	if float((plans[0] as Dictionary).get(&"recess", 0.0)) > 0.0:
		expected.append("Pier0")
	if float((plans[last] as Dictionary).get(&"recess", 0.0)) > 0.0:
		expected.append("Pier%d" % last if last > 0 else "Pier0High")
	for want in expected:
		if root.get_node_or_null(want) == null:
			var lot := 0 if want == "Pier0" else last
			violations.append("%s lot %d is recessed at the tile end but has no pier" % [where, lot])
	for child in root.get_children():
		if String(child.name).begins_with("Pier") and not expected.has(String(child.name)):
			violations.append("%s has an unexpected %s" % [where, child.name])
	return violations


## Lane violations for one tile: every visible, non-freed facade node under its own `Facades`
## child (not `SideStreets/*`, built far outside the lane) whose tile-local AABB intersects the
## raider lane. Adds to `counts[&"checked"]`.
static func tile_lane_violations(tile: Node3D, counts: Dictionary) -> Array[String]:
	var violations: Array[String] = []
	var facades := tile.get_node_or_null("Facades")
	if facades == null:
		return violations
	var lane_box := _FacadeKeepOut.lane_box()
	var inv: Transform3D = tile.global_transform.affine_inverse()
	var checked := 0
	for node in facades.find_children("*", "VisualInstance3D", true, false):
		if not _is_visible_under(node, tile) or _is_being_freed(node, tile):
			continue
		var local_aabb: AABB = _tile_local_aabb(node, inv)
		if lane_box.intersects(local_aabb):
			violations.append(
				"facade node %s (aabb %s) is in the raider lane" % [node.get_path(), local_aabb]
			)
		checked += 1
	counts[&"checked"] = int(counts.get(&"checked", 0)) + checked
	return violations


## The tile-local AABB a keep-out box is tested against: a `Light3D`'s own `get_aabb()` is its
## illumination range, not solid geometry, so it's reduced to a small cube at its origin; every
## other `VisualInstance3D` (meshes, decals, particles) keeps its transformed `get_aabb()`.
static func _tile_local_aabb(node: Node, inv: Transform3D) -> AABB:
	if node is Light3D:
		var local_pos: Vector3 = inv * (node as Node3D).global_transform.origin
		return _FacadeKeepOut.box_aabb(local_pos, _LIGHT_POINT_SIZE)
	return (inv * (node as Node3D).global_transform) * (node as VisualInstance3D).get_aabb()


## `node.visible` holds for it and every ancestor up to (not including) `tile`. A hidden stress
## host would make `is_visible_in_tree()` false for everything, so this is the shared substitute.
static func _is_visible_under(node: Node, tile: Node3D) -> bool:
	var n := node
	while n != null and n != tile:
		var n3 := n as Node3D
		if n3 != null and not n3.visible:
			return false
		n = n.get_parent()
	return true


## True when `node`, or an ancestor below `tile`, is queued for deletion or is the root of a
## renamed-before-free subtree (`rebuild_side`/`set_opening` name the old side `LeftOld` etc.
## before `queue_free()`; in a synchronous build that node is still in the tree when this runs).
static func _is_being_freed(node: Node, tile: Node3D) -> bool:
	var n := node
	while n != null and n != tile:
		if n.is_queued_for_deletion() or String(n.name).ends_with("Old"):
			return true
		n = n.get_parent()
	return false
