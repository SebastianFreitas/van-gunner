extends RefCounted
## Audit that every gap's infill mesh stands behind the gap's stepped-back face line.

const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")
const _FacadeInfill := preload("res://scripts/travel/facades/facade_infill.gd")

## 0.3 forward setback + 5 cm.
const FACE_SLACK := 0.35
## The walk's inner edge; gap furniture stands on the walk in front of the filler.
const WALK_X := 7.25


## Violations for one side: each `Infill*` mesh reaches no nearer the road than its gap's line.
static func violations(
	tile: Node3D, side: StringName, plans: Array, where: String
) -> Array[String]:
	var out: Array[String] = []
	if plans.is_empty() or plans[0].get(&"mouth", false):
		return out
	var root := tile.get_node_or_null("Facades/Left" if side == &"left" else "Facades/Right")
	if root == null:
		return out
	var spans := _FacadeInfill.gaps(plans)
	for child in root.get_children():
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var nm := String(mi.name)
		if not nm.begins_with("Infill") or nm.begins_with("@"):
			continue
		var digits := ""
		var i := nm.length() - 1
		while i >= 0 and nm[i] >= "0" and nm[i] <= "9":
			digits = nm[i] + digits
			i -= 1
		if digits.is_empty():
			continue
		var gi := digits.to_int()
		if gi >= spans.size():
			continue
		var g: float = _FacadePlan.gap_recess(plans, (spans[gi].x + spans[gi].y) * 0.5)
		var aabb: AABB = mi.transform * mi.mesh.get_aabb()
		var near := minf(absf(aabb.position.x), absf(aabb.end.x))
		var line: float = _FacadePlan.FACE_X + g - FACE_SLACK
		if nm.begins_with("InfillUtility") or nm.begins_with("InfillPole"):
			line = WALK_X + g
		if near < line - 0.001:
			out.append("%s %s reaches x %.3f, in front of its gap line %.3f (g %.2f)" % [
				where, nm, near, line, g])
	return out
