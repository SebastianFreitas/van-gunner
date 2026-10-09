class_name VanJunkLamp
extends Node3D
## Scavenged interior spot: a rusty tin can on a hose clamp with a bare bulb, a stub of wire run to a roof rib or wall bracket and a blob of weld, aimed at a point and owning one interior SpotLight3D (no fill omni, no shadows).

## Where the can points, in the parent's space (the can looks along its own -Z).
@export var aim_at := Vector3.ZERO
## Where the wire ends (a rib, a bracket), in the parent's space.
@export var anchor := Vector3.ZERO
@export var light_energy := 6.0
@export var light_range := 6.0
@export var light_color := Color(1.0, 0.78, 0.5, 1.0)
## Half-angle of the spot cone in degrees.
@export var spot_angle_deg := 65.0

## The lamp's interior light.
var light: SpotLight3D


func _ready() -> void:
	var dir := aim_at - position
	if dir.length() > 0.01:
		var up := Vector3.UP if absf(dir.normalized().y) < 0.95 else Vector3.RIGHT
		basis = Basis.looking_at(dir, up)
	_build()


func _build() -> void:
	var rust := MachineParts.dark(Color(0.30, 0.15, 0.08, 1.0), 0.9)
	var steel := MachineParts.dark(Color(0.14, 0.14, 0.15, 1.0), 0.85)
	var wire_mat := MachineParts.dark(Color(0.05, 0.045, 0.04, 1.0), 0.95)
	var bulb_mat := MachineParts.emissive(light_color, 3.0)

	_add_mesh("Can", _cyl(0.085, 0.17, 10, 0.07), rust, Vector3(0.0, 0.0, 0.085),
		Vector3(90.0, 0.0, 0.0))
	_add_mesh("Clamp", _torus(0.082, 0.007), steel, Vector3(0.0, 0.0, 0.07),
		Vector3(90.0, 0.0, 0.0))
	_add_mesh("Lip", _torus(0.088, 0.006), steel, Vector3(0.0, 0.0, -0.005),
		Vector3(90.0, 0.0, 0.0))
	_add_mesh("Socket", _cyl(0.022, 0.05, 8), steel, Vector3(0.0, 0.0, 0.0),
		Vector3(90.0, 0.0, 0.0))
	var bulb := _add_mesh("Bulb", _sphere(0.034), bulb_mat, Vector3(0.0, 0.0, -0.045))
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_mesh("Weld", _sphere(0.02), steel, Vector3(0.0, 0.07, 0.15))

	var to_anchor := basis.inverse() * (anchor - position)
	var reach := to_anchor.length()
	if reach > 0.02:
		var wire := _add_mesh("Wire", _cyl(0.006, reach, 5), wire_mat, to_anchor * 0.5)
		wire.basis = Basis.looking_at(to_anchor, Vector3.UP) * Basis(Vector3.RIGHT, deg_to_rad(90.0))
		_add_mesh("Staple", _cyl(0.014, 0.03, 6), steel, to_anchor)

	light = SpotLight3D.new()
	light.name = "Light"
	light.light_color = light_color
	light.light_energy = light_energy
	light.spot_range = light_range
	light.spot_angle = spot_angle_deg
	light.light_cull_mask = VanLighting.LAYER_VAN_INTERIOR
	light.light_volumetric_fog_energy = 0.0
	light.shadow_enabled = false
	light.position = Vector3(0.0, 0.0, -0.06)
	add_child(light)


func _add_mesh(mesh_name: String, mesh: Mesh, mat: Material, pos: Vector3,
		rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = mesh_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.layers = VanLighting.LAYER_VAN_INTERIOR
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
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
