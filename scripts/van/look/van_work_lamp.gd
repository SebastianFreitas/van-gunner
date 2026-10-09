class_name VanWorkLamp
extends Node3D
## Hanging caged work lamp: hook, cord, wire cage and a warm bulb that owns an interior downward SpotLight3D and sways with the van.

const CORD_LENGTH := 0.34
const CAGE_HEIGHT := 0.24
const CAGE_RADIUS := 0.065
const RIB_COUNT := 6
const PERIOD := 2.6
const SWAY_TRAVEL_DEG := 3.4
const SWAY_PARKED_DEG := 0.7
## Half-angle of the reflector cone, pointing straight down.
const SPOT_ANGLE_DEG := 70.0

@export var light_energy := 2.2
@export var light_range := 5.5
@export var light_color := Color(1.0, 0.82, 0.6, 1.0)
@export var phase_offset := 0.0
## Energy of the short bulb-level omni that lights the roof, ribs and nearby walls.
@export var fill_energy := 8.0
@export var fill_range := 2.0

## The lamp's interior light; a child of the swinging part so the pool follows the bulb.
var light: SpotLight3D
## Short-range all-round light at the bulb; the open cage throws light up and sideways too.
var fill: OmniLight3D

var _swing: Node3D
var _amp_deg := SWAY_PARKED_DEG
var _time := 0.0


func _ready() -> void:
	_time = phase_offset
	_build()


func _process(delta: float) -> void:
	_time += delta
	var travelling := GameSession.phase == GameSession.RunPhase.TRAVELLING
	var target := SWAY_TRAVEL_DEG if travelling else SWAY_PARKED_DEG
	# Slow ease so the swing settles after a stop instead of snapping.
	_amp_deg = lerpf(_amp_deg, target, 1.0 - exp(-0.8 * delta))
	var w := TAU * _time / PERIOD
	_swing.rotation = Vector3(
		deg_to_rad(_amp_deg) * sin(w),
		0.0,
		deg_to_rad(_amp_deg * 0.6) * sin(w * 0.93 + 1.1)
	)


func _build() -> void:
	var steel := MachineParts.dark(Color(0.16, 0.16, 0.17, 1.0), 0.85)
	var cord_mat := MachineParts.dark(Color(0.05, 0.045, 0.04, 1.0), 0.95)
	var bulb_mat := MachineParts.emissive(light_color, 3.0)

	_add_mesh(self, "Hook", _torus(0.02, 0.011), steel, Vector3(0.0, -0.015, 0.0),
		Vector3(90.0, 0.0, 0.0))

	_swing = Node3D.new()
	_swing.name = "Swing"
	add_child(_swing)

	_add_mesh(_swing, "Cord", _cyl(0.006, CORD_LENGTH, 6), cord_mat,
		Vector3(0.0, -CORD_LENGTH * 0.5 - 0.03, 0.0))

	var top := -CORD_LENGTH - 0.03
	_add_mesh(_swing, "Cap", _cyl(0.026, 0.03, 8, 0.04), steel, Vector3(0.0, top - 0.015, 0.0))
	var mid := top - 0.03 - CAGE_HEIGHT * 0.5
	for i in RIB_COUNT:
		var a := TAU * float(i) / float(RIB_COUNT)
		_add_mesh(_swing, "Rib_%d" % i, _cyl(0.0035, CAGE_HEIGHT, 4), steel,
			Vector3(cos(a) * CAGE_RADIUS, mid, sin(a) * CAGE_RADIUS))
	for r in 2:
		_add_mesh(_swing, "Ring_%d" % r, _torus(CAGE_RADIUS, 0.0045), steel,
			Vector3(0.0, mid + (CAGE_HEIGHT * 0.5 - 0.02) * (1.0 - 2.0 * float(r)), 0.0))
	var base := top - 0.03 - CAGE_HEIGHT
	_add_mesh(_swing, "Foot", _cyl(0.03, 0.02, 8), steel, Vector3(0.0, base - 0.01, 0.0))
	_add_mesh(_swing, "Socket", _cyl(0.02, 0.03, 8), steel, Vector3(0.0, mid + CAGE_HEIGHT * 0.5 - 0.015, 0.0))
	var bulb := _add_mesh(_swing, "Bulb", _sphere(0.036), bulb_mat, Vector3(0.0, mid - 0.01, 0.0))
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	light = SpotLight3D.new()
	light.name = "Light"
	light.light_color = light_color
	light.light_energy = light_energy
	light.spot_range = light_range
	light.spot_angle = SPOT_ANGLE_DEG
	light.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	light.light_cull_mask = VanLighting.LAYER_VAN_INTERIOR
	light.position = Vector3(0.0, mid - 0.01, 0.0)
	_swing.add_child(light)

	fill = OmniLight3D.new()
	fill.name = "Fill"
	fill.light_color = light_color
	fill.light_energy = fill_energy
	fill.omni_range = fill_range
	fill.light_cull_mask = VanLighting.LAYER_VAN_INTERIOR
	fill.light_specular = 0.0
	fill.position = light.position
	_swing.add_child(fill)


func _add_mesh(parent: Node3D, mesh_name: String, mesh: Mesh, mat: Material, pos: Vector3,
		rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = mesh_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.layers = VanLighting.LAYER_VAN_INTERIOR
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _cyl(radius: float, height: float, seg: int, bottom: float = -1.0) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius if bottom < 0.0 else bottom
	m.height = height
	m.radial_segments = seg
	m.rings = 1
	return m


func _torus(radius: float, thickness: float) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = maxf(radius - thickness, 0.001)
	m.outer_radius = radius + thickness
	m.rings = 12
	m.ring_segments = 4
	return m


func _sphere(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 10
	m.rings = 5
	return m
