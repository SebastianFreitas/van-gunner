class_name RearDoorDonorCabinArm
extends Node3D
## Cabin hinge of the donor leaf: a 3-stage telescoping hydraulic ram. A dark worn-steel main
## cylinder stands on the fixed pin (this node's position), a polished chrome stage slides out of
## its mouth and a thinner one out of that, each mouth wearing a bare-steel bevelled collar and a
## bright wiper ring. Stage 3 ends in a yoke whose two flat tines run back over the cylinder to the
## leaf's pin, so the pin never goes through a tube, closed or open. All tubes keep their length
## and are re-aimed and slid every frame; nothing is ever scaled. The extension is split evenly
## across the two sliding stages.

const LEN := 0.49
## Stages 2 and 3 are longer than the cylinder so the overlap stays 0.084 m at full stretch.
const LEN_STAGE := 0.52
## How far the cylinder's base cap reaches past the wall pin.
const END := 0.03
## Stage 3's tip stands this far past the leaf pin (the tines' run); closed, the tip sits just
## past the mouth collar (0.472).
const REACH := 0.107
## Outer radii. The sweep's worst clearance is 0.0572 at 110 deg, so nothing may exceed 0.0472
## (clearance minus the 1 cm margin); the collars and cap are the outermost parts.
const R_CYL := 0.043
const R_S2 := 0.034
const R_S3 := 0.024
const R_COLLAR1 := 0.047
const R_COLLAR2 := 0.043
const R_BASE := 0.047
const R_RING := 0.004
## Tines (width, length along the axis, thickness): flat plates above and below the axis, inner
## face 0.05 past the collar's 0.047, from the yoke block back to the leaf pin.
const TINE := Vector3(0.036, 0.15, 0.008)
const TINE_Y := 0.054

var _leaf: Node3D
var _pin: Vector3
var _s2: MeshInstance3D
var _s3: MeshInstance3D
var _collar2: MeshInstance3D
var _ring2: MeshInstance3D
var _yoke: Node3D
var _last_angle := INF


## `leaf` is the swinging `hinge` node, `pin` the ram's pivot in leaf space; this node's
## position (the fixed pin) is set by the caller in the leaf's parent space.
func setup(leaf: Node3D, pin: Vector3, mats: Dictionary) -> void:
	_leaf = leaf
	_pin = pin
	var body_mat: Material = mats["body"]
	var chrome_mat: Material = mats["chrome"]
	var collar_mat: Material = mats["collar"]
	var ring_mat: Material = mats["ring"]
	var weld_mat: Material = mats["weld"]
	# Along the ram's y axis from the wall pin; the cylinder's base cap sits END behind it.
	# The body ends at 0.44, inside collar 1 before its bevel narrows below R_CYL (at 0.445).
	_tube("CabinRamBody", R_CYL, body_mat, LEN - 0.02).position.y = LEN * 0.5 - END - 0.01
	_tube("CabinRamBase", R_BASE, weld_mat, 0.025).position.y = -END - 0.002
	_tube("CabinRamMouth", R_COLLAR1, collar_mat, 0.04, 0.8).position.y = LEN - END - 0.012
	_tube("CabinRamRing1", R_S2 + R_RING, ring_mat, 0.008).position.y = LEN - END + 0.012
	_s2 = _tube("CabinRamStage2", R_S2, chrome_mat, LEN_STAGE)
	_collar2 = _tube("CabinRamCollar2", R_COLLAR2, collar_mat, 0.03, 0.8)
	_ring2 = _tube("CabinRamRing2", R_S3 + R_RING, ring_mat, 0.008)
	_s3 = _tube("CabinRamStage3", R_S3, chrome_mat, LEN_STAGE)
	_yoke = Node3D.new()
	_yoke.name = "CabinRamYoke"
	add_child(_yoke)
	_instance("CabinRamYokeBlock", _box_mesh(Vector3(0.05, 0.03, 0.124)), weld_mat, _yoke)
	for s: float in [-1.0, 1.0]:
		var tine := _instance("CabinRamTine", _box_mesh(TINE), weld_mat, _yoke)
		tine.position = Vector3(0.0, 0.01 - TINE.y * 0.5, s * TINE_Y)
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
	var x := Vector3.UP.cross(y).normalized()
	basis = Basis(x, y, x.cross(y))
	# Stage 2 slides half the stretch out of the cylinder, stage 3 the same out of stage 2, so the
	# last tip ends REACH past the leaf pin. At the shortest length the stages sit in the cylinder.
	var half := maxf(dist + REACH - (LEN - END + 0.012), 0.0) * 0.5
	var tip2 := LEN - END + half + 0.006
	var tip3 := LEN - END + 0.012 + half * 2.0
	_s2.position.y = tip2 - LEN_STAGE * 0.5
	_collar2.position.y = tip2 - 0.014
	_ring2.position.y = tip2 + 0.005
	_s3.position.y = tip3 + 0.004 - LEN_STAGE * 0.5
	# The yoke's block starts at stage 3's tip; the tines run back from it to the leaf pin.
	_yoke.position.y = tip3 + 0.015
	# Fully collapsed the stages are inside the cylinder: hide them rather than leave nested
	# surfaces a few mm apart.
	for part: Node3D in [_s2, _collar2, _ring2, _s3]:
		part.visible = half > 0.001


func _box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


## `lip` shrinks the outer end's radius to make a bevel.
func _tube(node_name: String, r: float, mat: Material, length: float = LEN,
		lip: float = 1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = r * lip
	mesh.bottom_radius = r
	mesh.height = length
	mesh.radial_segments = 12
	mesh.rings = 1
	return _instance(node_name, mesh, mat, self)


func _instance(node_name: String, mesh: Mesh, mat: Material, parent: Node3D) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = mesh
	inst.material_override = mat
	inst.layers = 2
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.add_to_group(VanLighting.GROUP_EXTERIOR_LAYER)
	parent.add_child(inst)
	VanLighting.retarget_layers(inst, VanLighting.LAYER_STREET_AND_INTERIOR)
	return inst
