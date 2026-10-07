extends RefCounted
## Axle beams, differentials hanging below the belly and the 4x4 driveshaft between them, under the lifted van body; built under VanWheels by its rebuild_look.

## Differential housing (x, y, z) and how far its centre hangs below the hub, so most of it shows under the belly
## and its top stays 4 cm under the axle beam's top (the audit's 1 cm flicker rule).
const DIFF_SIZE := Vector3(0.44, 0.36, 0.38)
const DIFF_DROP := 0.17
## Driveshaft height: 10 cm under the hull's underside; its joints stop 5 mm under the cab's bottom (-0.29) and 4.5 cm above the diffs' bottom.
const SHAFT_Y := VanWheels.HULL_BOTTOM_Y - 0.10
## Shaft thickness: 2 cm inside each joint's faces, and its ends tuck 3 cm into the joints (flicker rule).
const SHAFT_T := 0.07
const SHAFT_TUCK := 0.03
## U-joint block at each shaft end.
const JOINT_SIZE := 0.11

var _wheels: VanWheels
var _steel: StandardMaterial3D


func _init(wheels: VanWheels) -> void:
	_wheels = wheels
	_steel = StandardMaterial3D.new()
	_steel.albedo_color = Color(0.09, 0.085, 0.08)
	_steel.roughness = 0.75
	_steel.metallic = 0.3


func build(rear_axles: Array[float]) -> void:
	var front_hub_y := VanWheels.ROAD_Y + VanWheels.FRONT_RADIUS
	_beam("AxleFront", VanWheels.FRONT_AXLE_Z, front_hub_y,
			VanWheels.WHEEL_X + VanWheels.FRONT_WHEEL_OUT)
	_diff("DiffFront", VanWheels.FRONT_AXLE_Z, front_hub_y, -1.0)
	var rear_hub_y := VanWheels.ROAD_Y + VanWheels.REAR_RADIUS
	for i: int in range(rear_axles.size()):
		var z: float = rear_axles[i]
		_beam("AxleRear%d" % i, z, rear_hub_y, VanWheels.REAR_WHEEL_X)
		var cover := 1.0 if i == rear_axles.size() - 1 else 0.0
		_diff("DiffRear%d" % i, z, rear_hub_y, cover)

	_shaft("Driveshaft", VanWheels.FRONT_AXLE_Z + 0.18, rear_axles[0] - 0.18, SHAFT_Y)
	if rear_axles.size() > 1:
		_shaft("DriveshaftTandem", rear_axles[0] + 0.18, rear_axles[1] - 0.18, SHAFT_Y)


func _diff(diff_name: String, z: float, hub_y: float, cover_dir: float) -> void:
	_box(diff_name, DIFF_SIZE, Vector3(0.0, hub_y - DIFF_DROP, z))
	if cover_dir != 0.0:
		_box(diff_name + "Cover", Vector3(0.30, 0.26, 0.06),
				Vector3(0.0, hub_y - DIFF_DROP, z + cover_dir * (DIFF_SIZE.z * 0.5 + 0.02)))


func _shaft(shaft_name: String, z_from: float, z_to: float, y: float) -> void:
	_box(shaft_name, Vector3(SHAFT_T, SHAFT_T, z_to - z_from - 2.0 * SHAFT_TUCK),
			Vector3(0.0, y, (z_from + z_to) * 0.5))
	_box(shaft_name + "Joint0", Vector3.ONE * JOINT_SIZE,
			Vector3(0.0, y, z_from + JOINT_SIZE * 0.5))
	_box(shaft_name + "Joint1", Vector3.ONE * JOINT_SIZE,
			Vector3(0.0, y, z_to - JOINT_SIZE * 0.5))


func _beam(beam_name: String, z: float, hub_y: float, wheel_x: float) -> void:
	_box(beam_name, Vector3(2.0 * wheel_x - VanWheels.TYRE_WIDTH, 0.10, 0.10),
			Vector3(0.0, hub_y, z))


func _box(box_name: String, size: Vector3, pos: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.name = box_name
	mi.mesh = mesh
	mi.material_override = _steel
	mi.layers = 1
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mi.position = pos
	_wheels.add_child(mi)
