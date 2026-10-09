class_name VanFloorLamp
extends RefCounted
## The scavenged caged trouble lamp that lights the stairs down to the back room.

const _FACE_Z := 1.06
const _CENTER := Vector3(-1.60, 1.70, 1.14)
const _AMBER := Color(1.0, 0.55, 0.22)


## Builds `StairsLamp` under `parent`: hanger plate on the bulkhead's back-room face, a bar down
## to the cage, the bulb and its amber light (the `_trouble_lamp` recipe, no shadow).
static func build(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "StairsLamp"
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.16, 0.16, 0.15)
	steel.roughness = 0.75
	steel.metallic = 0.3
	_box(root, "Hanger", Vector3(0.06, 0.06, 0.01), steel, Vector3(_CENTER.x, 1.82, _FACE_Z + 0.005))
	_box(root, "Arm", Vector3(0.012, 0.012, _CENTER.z - _FACE_Z), steel,
			Vector3(_CENTER.x, 1.82, (_FACE_Z + _CENTER.z) * 0.5))
	_box(root, "Drop", Vector3(0.012, 0.07, 0.012), steel, Vector3(_CENTER.x, 1.785, _CENTER.z))
	_ring(root, "CageTop", 0.06, steel, _CENTER + Vector3(0.0, 0.05, 0.0))
	_ring(root, "CageBottom", 0.055, steel, _CENTER + Vector3(0.0, -0.05, 0.0))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_box(root, "CageBar", Vector3(0.008, 0.1, 0.008), steel,
					_CENTER + Vector3(sx * 0.05, 0.0, sz * 0.05))
	var sphere := SphereMesh.new()
	sphere.radius = 0.035
	sphere.height = 0.07
	sphere.radial_segments = 8
	sphere.rings = 4
	var bulb := MeshInstance3D.new()
	bulb.name = "Bulb"
	bulb.mesh = sphere
	bulb.material_override = MachineParts.emissive(_AMBER, 1.6)
	bulb.layers = VanLighting.LAYER_VAN_INTERIOR
	bulb.position = _CENTER
	root.add_child(bulb)
	var light := OmniLight3D.new()
	light.name = "Light"
	light.light_color = _AMBER
	light.light_energy = 0.9
	light.omni_range = 1.7
	light.shadow_enabled = false
	light.light_cull_mask = VanLighting.LAYER_VAN_INTERIOR
	light.position = _CENTER
	root.add_child(light)
	parent.add_child(root)


static func _box(
	root: Node3D, node_name: String, size: Vector3, mat: Material, pos: Vector3
) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_add(root, node_name, mesh, mat, pos)


static func _ring(
	root: Node3D, node_name: String, radius: float, mat: Material, pos: Vector3
) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.012
	mesh.radial_segments = 10
	_add(root, node_name, mesh, mat, pos)


static func _add(root: Node3D, node_name: String, mesh: Mesh, mat: Material, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.layers = VanLighting.LAYER_VAN_INTERIOR
	mi.position = pos
	root.add_child(mi)
