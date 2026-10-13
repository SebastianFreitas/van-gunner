class_name RearDoorDonorCabinArm
extends Node3D
## Moving half of the cabin hinge's tube: a bare rod that turns about the elbow on the fixed post
## side and slides in and out of a fat sleeve welded to the leaf, re-aimed every frame at the pin.

const SLEEVE_R := 0.042
const SLEEVE_LEN := 0.28

var _leaf: Node3D
var _pin: Vector3
var _rod: MeshInstance3D
var _sleeve: MeshInstance3D
var _last_angle := INF


## `leaf` is the swinging `hinge` node, `pin` the sleeve's pivot in leaf space; this node's
## position (the elbow) is set by the caller in the leaf's parent space.
func setup(leaf: Node3D, pin: Vector3, rod_r: float, rod_mat: Material, sleeve_mat: Material) -> void:
	_leaf = leaf
	_pin = pin
	_rod = _cylinder("CabinArmRod", rod_r, rod_mat)
	_sleeve = _cylinder("CabinArmSleeve", SLEEVE_R, sleeve_mat)
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
	# The rod ends inside the sleeve, which always ends on the pin.
	var rod_len := maxf(dist - SLEEVE_LEN * 0.5, 0.01)
	_rod.scale = Vector3(1.0, rod_len, 1.0)
	_rod.position = Vector3(0.0, rod_len * 0.5, 0.0)
	_sleeve.scale = Vector3(1.0, SLEEVE_LEN, 1.0)
	_sleeve.position = Vector3(0.0, dist - SLEEVE_LEN * 0.5, 0.0)


## Unit-height cylinder on the same layers as the rest of the hinge; `scale.y` sets its length.
func _cylinder(node_name: String, r: float, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = r
	mesh.bottom_radius = r
	mesh.height = 1.0
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
