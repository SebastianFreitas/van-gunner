extends RefCounted
## Wreck pass: bends signs, sags awnings and tips street furniture on worn and ruined buildings.

const _FacadeRuin := preload("res://scripts/travel/facades/facade_ruin.gd")

enum Kind { NONE, SIGN, AWNING, FURNITURE }

## Node-name prefixes the sign, awning and furniture families make (facade_signs.gd and
## facade_props_ground.gd); everything else (merged upper props, bodies, rubble) stays as built.
const _SIGN_PREFIXES: Array[String] = ["Sign"]
const _AWNING_PREFIXES: Array[String] = ["Awning"]
const _FURNITURE_PREFIXES: Array[String] = [
	"Hydrant", "NewsBox", "Dumpster", "Bench", "Booth", "Vending", "Bollards", "Crate"
]
## Chance per classified node, indexed by the ruin tier (INTACT, WORN, BROKEN, GUTTED).
const _CHANCE: Array[float] = [0.05, 0.35, 0.6, 0.8]
## Lowest a wrecked node's AABB may reach: tilting about a bottom edge dips a corner a little.
const _MIN_Y := -0.35


## The tile keep-out boxes are tile-local and the side root is an unrotated, unscaled Node3D at the
## tile origin, so a node's host-local AABB is exactly the frame keep_out.allows expects.
static func wreck(
	host: Node3D, from_child: int, plan: Dictionary, side_sign: float, keep_out: RefCounted
) -> void:
	if plan.get(&"mouth", false) or plan.get(&"rare", &"") != &"":
		return
	var tier := clampi(int(plan.get(&"ruin", 0)), _FacadeRuin.INTACT, _FacadeRuin.GUTTED)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([float(plan[&"params"][&"seed"]), &"wreck"])
	var children := host.get_children()
	for idx in range(from_child, children.size()):
		var node := children[idx] as MeshInstance3D
		if node == null or node.mesh == null:
			continue
		var node_name := String(node.name)
		if node_name.begins_with("Body") or node_name.begins_with("Ruin"):
			continue
		var kind := _classify(node_name)
		if kind == Kind.NONE or rng.randf() >= _CHANCE[tier]:
			continue
		var aabb := node.mesh.get_aabb()
		var old := node.transform
		var new_xf := _wrecked(kind, old * aabb, old, side_sign, rng)
		var nb := new_xf * aabb
		if not keep_out.allows(nb) or nb.position.y < _MIN_Y:
			continue
		# A glow panel is its own node right after its body: it moves with the body or not at all,
		# or it would float where the furniture used to stand.
		var glow: MeshInstance3D = null
		if kind == Kind.FURNITURE and idx + 1 < children.size():
			glow = children[idx + 1] as MeshInstance3D
			if glow != null and (glow.mesh == null or not String(glow.name).contains("Glow")):
				glow = null
		if glow != null:
			var delta := new_xf * old.affine_inverse()
			var gb := (delta * glow.transform) * glow.mesh.get_aabb()
			if not keep_out.allows(gb):
				continue
			glow.transform = delta * glow.transform
		node.transform = new_xf


static func _classify(node_name: String) -> Kind:
	for prefix in _SIGN_PREFIXES:
		if node_name.begins_with(prefix):
			return Kind.SIGN
	for prefix in _AWNING_PREFIXES:
		if node_name.begins_with(prefix):
			return Kind.AWNING
	for prefix in _FURNITURE_PREFIXES:
		# A digit must follow, so "BoothGlow0" (the emissive panel) is not a body.
		if node_name.begins_with(prefix) and node_name.substr(prefix.length()).is_valid_int():
			return Kind.FURNITURE
	return Kind.NONE


## The wrecked transform of a node whose host-local box is `box` and whose transform is `old`.
static func _wrecked(
	kind: Kind, box: AABB, old: Transform3D, side_sign: float, rng: RandomNumberGenerator
) -> Transform3D:
	var axis := Vector3.RIGHT
	var angle := 0.0
	var pivot := Vector3(box.get_center().x, box.end.y, 0.0)
	# The wall is on the side_sign side: its face is the box's larger-|x| face.
	var wall_x := box.end.x if side_sign > 0.0 else box.position.x
	var low_end := rng.randf() < 0.5
	var z_end := box.position.z if low_end else box.end.z
	# Pivot at the low z end: rotating by + about X drops the far (+z) end, so the sign flips with
	# the end and the other end always drops (or the body falls out past the pivot end).
	var along := 1.0 if low_end else -1.0
	match kind:
		Kind.SIGN:
			if box.size.x > box.size.z:
				# A blade off the wall: pivot at its wall-side top, the outer (road) end goes down.
				axis = Vector3.BACK
				angle = side_sign * rng.randf_range(0.12, 0.45)
				pivot = Vector3(wall_x, box.end.y, box.get_center().z)
			else:
				# Flat on the wall, hanging by one bolt.
				angle = along * rng.randf_range(0.12, 0.45)
				pivot.z = z_end
		Kind.AWNING:
			angle = along * rng.randf_range(0.08, 0.25)
			pivot = Vector3(wall_x, box.end.y, z_end)
		Kind.FURNITURE:
			# Falls along z, never toward the road; the pivot is the bottom edge at the fall end.
			pivot = Vector3(box.get_center().x, box.position.y, z_end)
			if rng.randf() < 0.3:
				angle = -along * PI * 0.5
			else:
				angle = -along * rng.randf_range(0.15, 0.5)
	var rot := Transform3D(Basis(axis, angle), Vector3.ZERO)
	return Transform3D(Basis.IDENTITY, pivot) * rot * Transform3D(Basis.IDENTITY, -pivot) * old
