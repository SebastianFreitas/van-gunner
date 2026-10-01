extends RefCounted
## Axle beams, differentials and driveshafts under the lifted van body, at the wheels' hub height; built under VanWheels by its rebuild_look.

var _wheels: VanWheels
var _steel: StandardMaterial3D


func _init(wheels: VanWheels) -> void:
	_wheels = wheels
	_steel = StandardMaterial3D.new()
	_steel.albedo_color = Color(0.09, 0.085, 0.08)
	_steel.roughness = 0.75
	_steel.metallic = 0.3


func build(rear_axles: Array[float]) -> void:
	_beam("AxleFront", VanWheels.FRONT_AXLE_Z, VanWheels.ROAD_Y + VanWheels.FRONT_RADIUS,
			VanWheels.WHEEL_X + VanWheels.FRONT_WHEEL_OUT)
	var rear_hub_y := VanWheels.ROAD_Y + VanWheels.REAR_RADIUS
	for i: int in range(rear_axles.size()):
		var z: float = rear_axles[i]
		_beam("AxleRear%d" % i, z, rear_hub_y, VanWheels.WHEEL_X)
		_box("DiffRear%d" % i, Vector3(0.36, 0.26, 0.30), Vector3(0.0, rear_hub_y - 0.02, z))

	var shaft_y := rear_hub_y - 0.02
	_shaft("Driveshaft", VanWheels.FRONT_AXLE_Z + 0.6, rear_axles[0] - 0.15, shaft_y)
	if rear_axles.size() > 1:
		_shaft("DriveshaftTandem", rear_axles[0] + 0.15, rear_axles[1] - 0.15, shaft_y)


func _shaft(shaft_name: String, z_from: float, z_to: float, y: float) -> void:
	_box(shaft_name, Vector3(0.08, 0.08, z_to - z_from), Vector3(0.0, y, (z_from + z_to) * 0.5))


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
