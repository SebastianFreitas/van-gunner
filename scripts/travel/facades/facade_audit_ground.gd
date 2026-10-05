extends RefCounted
## Audit that each lot's street furniture and ruin rubble stand behind the lot's recessed kerb.

## Furniture mesh name prefixes (facade_props_ground.gd); the suffix is the piece index.
const FURNITURE := [
	"Hydrant", "NewsBox", "Dumpster", "Bench", "Booth", "Vending", "Bollards", "Crate"
]
## The recess-0 kerb line the lot's recess is added to.
const KERB_X := 7.75
const SLACK := 0.05


## Violations for one side: furniture reaches no nearer the road than 7.75 + r, rubble 7.75 +
## kerb r (0 for a plaza lot). A furniture piece belongs to the lot its centre z falls in.
static func violations(
	tile: Node3D, side: StringName, plans: Array, where: String
) -> Array[String]:
	var out: Array[String] = []
	if plans.is_empty() or plans[0].get(&"mouth", false):
		return out
	var root := tile.get_node_or_null("Facades/Left" if side == &"left" else "Facades/Right")
	if root == null:
		return out
	for child in root.get_children():
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var nm := String(mi.name)
		var aabb: AABB = mi.transform * mi.mesh.get_aabb()
		var near := minf(absf(aabb.position.x), absf(aabb.end.x))
		var is_rubble := nm.begins_with("Ruin") and nm.ends_with("Rubble")
		var plan: Dictionary = {}
		if is_rubble:
			var li := nm.trim_prefix("Ruin").trim_suffix("Rubble").to_int()
			if li < plans.size():
				plan = plans[li]
		elif _is_furniture(nm):
			var cz := aabb.position.z + aabb.size.z * 0.5
			for p in plans:
				if cz >= float(p[&"z0"]) and cz <= float(p[&"z1"]):
					plan = p
					break
		if plan.is_empty():
			continue
		var r := float(plan.get(&"recess", 0.0))
		if is_rubble and bool(plan.get(&"plaza", false)):
			r = 0.0
		var line := KERB_X + r - SLACK
		if near < line:
			out.append("%s %s reaches x %.3f, in front of its lot's line %.3f (r %.2f)" % [
				where, nm, near, line, r])
	return out


static func _is_furniture(nm: String) -> bool:
	for prefix in FURNITURE:
		if nm.begins_with(prefix):
			var rest := nm.substr(prefix.length())
			return not rest.is_empty() and rest.is_valid_int()
	return false
