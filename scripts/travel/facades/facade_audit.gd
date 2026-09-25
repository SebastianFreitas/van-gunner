extends RefCounted
## Shared keep-out audits for a corridor tile's built facades: the bay-mouth clearance check
## (nothing built in front of a stop-bay opening) and the raider-lane clearance check (nothing
## built in the road below y=6). The smoke test and the `facade` debug console commands both
## call these so the two never drift apart.


const _FacadeKeepOut := preload("res://scripts/travel/facades/facade_keep_out.gd")

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
