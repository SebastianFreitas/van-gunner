class_name RearDoorDonorTopRam
extends Node3D
## Top ram of the donor leaf (blockout): a body rod pinned to the arch bracket under the rear arch's
## header and a door rod pinned to the leaf's free top corner slide into a twin sleeve, two parallel
## tubes stacked in y (door rod in the lower, body rod in the upper, so the rods pass each other).
## The sleeve stays centred on the pin midpoint and aimed along the pin line; every part keeps its
## length, only the positions along the line change as the leaf's `rotation.y` changes. Built by
## `RearDoorDonorTopRamBuild`, which holds the plates and pins.
##
## Sweep (`sweep()`, hinge-local xz, leaf 0..110 deg every 5 deg, body pin (0.60, -0.34), door pin
## (2.10, -0.33)): pin distance D 1.500 closed to 2.627 open. Sleeve S 0.72, rod length L 1.06 from
## the pin centre: at D max each rod keeps 0.107 m in its tube (needs >= 0.05, L >= (D max - S) / 2
## + 0.05), at D min each tip stops 0.050 m short of the tube's far end (L <= (D min + S) / 2). The
## ram stays on the leaf's cabin side the whole swing (worst clearance of the tube surface to the
## leaf's back and the pillar ring is about 0.034 m, closed).

const S := 0.72
const L := 1.06
const R_TUBE := 0.026
const R_ROD := 0.014
## The two tubes' axes stand this far above and below the pin line.
const STACK := 0.03
## A rod starts this far behind its pin so the pin sits inside its end.
const BEHIND := 0.02
## Pin positions: hinge-local x, z of the body pin (arch bracket) and the door pin (leaf plate).
const WALL_XZ := Vector2(0.60, -0.34)
const DOOR_XZ := Vector2(2.10, -0.33)
## Hinge-local pillar deep ring (x <= PILLAR_X, z >= PILLAR_Z, up to the wall's street face) and the
## leaf's back (its beam and iron box), the depth the swept-leaf checks use.
const PILLAR_X := -0.10
const PILLAR_Z := -0.45
const PILLAR_END_Z := 0.08
const LEAF_BACK_Z := -0.27
const _STEP_DEG := 5
const _OPEN_DEG := 110

var _leaf: Node3D
var _pin: Vector3
var _door_tube: MeshInstance3D
var _body_tube: MeshInstance3D
var _door_rod: MeshInstance3D
var _body_rod: MeshInstance3D
var _last_angle := INF


## `leaf` is the swinging `hinge` node, `pin` the door pin in leaf space; this node's position
## (the wall pin) is set by the caller in the leaf's parent space.
func setup(leaf: Node3D, pin: Vector3, mats: Dictionary) -> void:
	_leaf = leaf
	_pin = pin
	var rod_mat: Material = mats["rod"]
	var sleeve_mat: Material = mats["sleeve"]
	_door_tube = _tube("TwinSleeveDoorTube", R_TUBE, S, sleeve_mat)
	_body_tube = _tube("TwinSleeveBodyTube", R_TUBE, S, sleeve_mat)
	_door_rod = _tube("DoorRod", R_ROD, L + BEHIND, rod_mat)
	_body_rod = _tube("BodyRod", R_ROD, L + BEHIND, rod_mat)
	_aim()


func _process(_delta: float) -> void:
	if _leaf != null and not is_equal_approx(_leaf.rotation.y, _last_angle):
		_aim()


func _aim() -> void:
	_last_angle = _leaf.rotation.y
	var dir := _leaf.transform * _pin - position
	var dist := dir.length()
	if dist < 0.001:
		return
	var y := dir / dist
	# Local y runs along the pin line, local z is up: the tubes stack in z.
	basis = Basis(y.cross(Vector3.UP), y, Vector3.UP)
	_door_tube.position = Vector3(0.0, dist * 0.5, -STACK)
	_body_tube.position = Vector3(0.0, dist * 0.5, STACK)
	_door_rod.position = Vector3(0.0, dist - (L - BEHIND) * 0.5, -STACK)
	_body_rod.position = Vector3(0.0, (L - BEHIND) * 0.5, STACK)


## Samples the swing and returns the smoke line: min_overlap (worst rod-in-tube length, at D max),
## max_tip_inside (worst margin of a rod tip short of its tube's far end, at D min),
## min_clearance (tube surface to the pillar ring and the leaf's slab) and closed_gap (closed, the
## ram's cabin-most surface to the leaf's back).
static func sweep() -> String:
	var min_overlap := INF
	var tip_margin := INF
	var min_clear := INF
	for deg in range(0, _OPEN_DEG + 1, _STEP_DEG):
		var rot := Basis(Vector3.UP, -deg_to_rad(float(deg)))
		var door := rot * Vector3(DOOR_XZ.x, 0.0, DOOR_XZ.y)
		var wall := Vector3(WALL_XZ.x, 0.0, WALL_XZ.y)
		var d := (door - wall).length()
		min_overlap = minf(min_overlap, L - (d - S) * 0.5)
		tip_margin = minf(tip_margin, (d + S) * 0.5 - L)
		for k in 41:
			var p := wall.lerp(door, float(k) / 40.0)
			var q := rot.inverse() * p
			if p.z <= PILLAR_END_Z and p.x >= -0.46:
				var pillar := Vector2(maxf(p.x - PILLAR_X, 0.0), maxf(PILLAR_Z - p.z, 0.0)).length()
				min_clear = minf(min_clear, pillar - R_TUBE)
			var leaf := Vector2(maxf(maxf(-q.x, q.x - VanInteriorSize.REAR_DOOR_HALF), 0.0),
					maxf(maxf(LEAF_BACK_Z - q.z, q.z - PILLAR_END_Z), 0.0)).length()
			min_clear = minf(min_clear, leaf - R_TUBE)
	var closed_gap := LEAF_BACK_Z - (maxf(WALL_XZ.y, DOOR_XZ.y) + R_TUBE)
	return "top ram sweep: min_overlap=%.3f max_tip_inside=%.3f min_clearance=%.3f closed_gap=%.3f" \
			% [min_overlap, tip_margin, min_clear, closed_gap]


## Closest the leaf's slab (hinge-local x 0..REAR_DOOR_HALF, z LEAF_BACK_Z..0.08) gets to the HV
## leads' hanging loops, floor battery and strap foot over the 0..110 deg swing, in the xz plane,
## less the lead radius; also the leads' gap to the pillar ring, whichever is smaller.
static func lead_clearance() -> float:
	var best := RearDoorDonorTopRamPower.keepout_clearance()
	for deg in range(0, _OPEN_DEG + 1, _STEP_DEG):
		var inv := Basis(Vector3.UP, deg_to_rad(float(deg)))
		for p in RearDoorDonorTopRamPower.xz_points():
			var q := inv * Vector3(p.x, 0.0, p.y)
			var d := Vector2(maxf(maxf(-q.x, q.x - VanInteriorSize.REAR_DOOR_HALF), 0.0),
					maxf(maxf(LEAF_BACK_Z - q.z, q.z - 0.08), 0.0)).length()
			best = minf(best, d - RearDoorDonorTopRamPower.CABLE_R)
	return best


## Smoke check on the built nodes with the leaf at 0 and 110 deg (the angle is restored): returns
## the sweep line's `pin_err=<m>` (largest distance of `BodyPin` to this node's body-side pivot and
## of `DoorPin` to the door end) and the names of top ram meshes whose global AABB leaves the van's
## interior box (the open leaf swings its width past the rear, and the door pin with it).
func check_built() -> Dictionary:
	var rig: Node = self
	while rig != null and rig.name != &"VanRig":
		rig = rig.get_parent()
	var frame := get_parent()
	var body_pin: Node3D = null
	var door_pin: Node3D = null
	var meshes: Array[Node3D] = []
	var power := frame.get_node_or_null("TopRamPower")
	if power != null:
		for node in power.get_children():
			meshes.append(node as Node3D)
	for node in frame.get_children() + _leaf.get_children():
		var label := str(node.name)
		if node is MeshInstance3D and (label.begins_with("BodyPin") or label.begins_with("DoorPin")
				or label.begins_with("ArchBracket") or label.begins_with("DoorPlate")
				or label.begins_with("TopRamBolt")):
			meshes.append(node)
			if label.begins_with("BodyPin") and not label.begins_with("BodyPinLug"):
				body_pin = node
			elif label.begins_with("DoorPin") and not label.begins_with("DoorPinLug"):
				door_pin = node
	if body_pin == null or door_pin == null:
		return {"pin_err": INF, "outside": []}
	for node in get_children():
		meshes.append(node as Node3D)
	var saved := _leaf.rotation.y
	var err := 0.0
	var outside: Array[String] = []
	for deg in [0, _OPEN_DEG]:
		_leaf.rotation.y = -deg_to_rad(float(deg))
		_aim()
		err = maxf(err, body_pin.global_position.distance_to(global_position))
		err = maxf(err, door_pin.global_position.distance_to(_leaf.to_global(_pin)))
		var swing := VanInteriorSize.REAR_DOOR_HALF if deg > 0 else 0.0
		var box := AABB(Vector3(-VanInteriorSize.BOTTOM_HALF, 0.0, VanInteriorSize.FRONT_Z),
				Vector3(2.0 * VanInteriorSize.BOTTOM_HALF, VanInteriorSize.WALL_HEIGHT,
				VanInteriorSize.REAR_Z - VanInteriorSize.FRONT_Z + swing)).grow(0.001)
		for node in meshes:
			var mesh := node as MeshInstance3D
			var local: AABB = (rig as Node3D).global_transform.affine_inverse() \
					* mesh.global_transform * mesh.get_aabb()
			if not box.encloses(local) and not outside.has(str(node.name)):
				outside.append(str(node.name))
	_leaf.rotation.y = saved
	_aim()
	return {"pin_err": err, "outside": outside}


func _tube(node_name: String, r: float, length: float, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = r
	mesh.bottom_radius = r
	mesh.height = length
	mesh.radial_segments = 10
	mesh.rings = 1
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = mesh
	inst.material_override = mat
	inst.layers = 2
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.add_to_group(VanLighting.GROUP_EXTERIOR_LAYER)
	add_child(inst)
	VanLighting.retarget_layers(inst, VanLighting.LAYER_STREET_AND_INTERIOR)
	return inst
