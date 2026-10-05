extends RefCounted
## Audit that wall lamps hang at their lot's recessed face and gap weeds stay behind the gap's.

const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")

## A lamp hangs 0 to this far road-ward of its face (facade_fixtures.gd).
const LAMP_REACH := 1.0
## Weed blades may lean this far in front of the gap's face line.
const WEED_LEAN := 0.9
const SLACK := 0.01


## Violations for one side: each `facade_lights` node sits within LAMP_REACH road-ward of the face
## of the lot at its z (the nearest lot over a gap), and each `GrowthGap` mesh reaches no nearer
## the road than 8.8 + gap recess - WEED_LEAN.
static func violations(
	tile: Node3D, side: StringName, plans: Array, where: String
) -> Array[String]:
	var out: Array[String] = []
	if plans.is_empty() or plans[0].get(&"mouth", false):
		return out
	var root := tile.get_node_or_null("Facades/Left" if side == &"left" else "Facades/Right")
	if root == null:
		return out
	var to_tile := tile.global_transform.affine_inverse()
	for light in tile.get_tree().get_nodes_in_group(&"facade_lights"):
		var node := light as Node3D
		if node == null or not root.is_ancestor_of(node):
			continue
		var p := to_tile * node.global_position
		var plan := _lot_at(plans, p.z)
		if plan.is_empty():
			continue
		var face := absf(_FacadePlan.face_x(plan, 1.0))
		var x := absf(p.x)
		if x < face - LAMP_REACH - SLACK or x > face + SLACK:
			out.append("%s %s at x %.3f, outside face %.3f - %.1f..0 (r %.2f)" % [
				where, node.name, x, face, LAMP_REACH, float(plan.get(&"recess", 0.0))])
	for child in root.get_children():
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null or not String(mi.name).begins_with("GrowthGap"):
			continue
		var aabb: AABB = mi.transform * mi.mesh.get_aabb()
		var cz := aabb.position.z + aabb.size.z * 0.5
		var line := _FacadePlan.FACE_X + _FacadePlan.gap_recess(plans, cz) - WEED_LEAN
		var near := minf(absf(aabb.position.x), absf(aabb.end.x))
		if near < line:
			out.append("%s %s reaches x %.3f, in front of its gap's line %.3f" % [
				where, mi.name, near, line])
	return out


## Violations for the tile's overhead: each span mesh ends within 5 cm of 9.2 + the recess of its
## side's lots at its z extent (beams 9.0, rib posts 8.3 +- 0.3). Adds the meshes checked to
## `counts[&"overheads"]`.
static func overhead_violations(
	tile: Node3D, plans_left: Array, plans_right: Array, where: String, counts: Dictionary
) -> Array[String]:
	var out: Array[String] = []
	var to_tile := tile.global_transform.affine_inverse()
	var children: Array[Node] = []
	for root_path in ["Facades/Overhead", "Facades/Span"]:
		var root := tile.get_node_or_null(root_path)
		# A span dropped by a later opening change is queued for free but still in the tree.
		if root != null and not root.is_queued_for_deletion():
			children.append_array(root.get_children())
	for child in children:
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var n := String(mi.name)
		var bridge := n == "Bridge" or (n.begins_with("Pipe") and n.length() == 5)
		if not bridge and (not n.begins_with("Overhead") or n.begins_with("OverheadHangers")
				or n.begins_with("OverheadTrussDiag")):
			continue
		var aabb: AABB = to_tile * mi.global_transform * mi.mesh.get_aabb()
		if bridge:
			# The pedestrian bridge's end portals are 0.4 thick, centred on 9.2 + recess.
			var span_base := 9.4 if n == "Bridge" else 9.2
			var b_l := _FacadePlan.recess_at(plans_left, aabb.position.z, aabb.end.z)
			var b_r := _FacadePlan.recess_at(plans_right, aabb.position.z, aabb.end.z)
			counts[&"bridges"] = int(counts.get(&"bridges", 0)) + 1
			if absf(aabb.end.x - (span_base + b_r)) > 0.05 \
					or absf(aabb.position.x + span_base + b_l) > 0.05:
				out.append("%s %s spans x %.3f..%.3f, expected -%.3f..%.3f" % [
					where, n, aabb.position.x, aabb.end.x, span_base + b_l, span_base + b_r])
			continue
		# The builder looks the recess up over z -1..1 for the catwalk (its rails reach 1.025).
		var z0 := -7.3 if n.begins_with("OverheadRib") else (-1.0 if n.begins_with("OverheadCatwalk") else aabb.position.z)
		var z1 := 7.3 if n.begins_with("OverheadRib") else (1.0 if n.begins_with("OverheadCatwalk") else aabb.end.z)
		var rec_l := _FacadePlan.recess_at(plans_left, z0, z1)
		var rec_r := _FacadePlan.recess_at(plans_right, z0, z1)
		counts[&"overheads"] = int(counts.get(&"overheads", 0)) + 1
		if n.begins_with("OverheadRibPosts"):
			var cx := aabb.position.x + aabb.size.x * 0.5
			var want := -(8.3 + rec_l) if n.ends_with("Left") else 8.3 + rec_r
			if absf(cx - want) > 0.3:
				out.append("%s %s post at x %.3f, expected %.3f" % [where, n, cx, want])
			continue
		var base := 9.0 if n == "OverheadRibBeams" else 9.2
		if absf(aabb.end.x - (base + rec_r)) > 0.05 or absf(aabb.position.x + base + rec_l) > 0.05:
			out.append("%s %s spans x %.3f..%.3f, expected -%.3f..%.3f" % [
				where, n, aabb.position.x, aabb.end.x, base + rec_l, base + rec_r])
	return out


## The lot whose z span holds z, else the nearest non-mouth lot (a lamp over a gap snaps to it).
static func _lot_at(plans: Array, z: float) -> Dictionary:
	var best := INF
	var nearest: Dictionary = {}
	for plan: Dictionary in plans:
		if bool(plan.get(&"mouth", false)):
			continue
		var d := maxf(maxf(float(plan[&"z0"]) - z, z - float(plan[&"z1"])), 0.0)
		if d < best:
			best = d
			nearest = plan
	return nearest
