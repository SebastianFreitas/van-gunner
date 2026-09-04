class_name ArmCannonMesh
extends Object

## Boxy Mega Man forearm cannons. Rear face stays at REAR_Z so length grows
## toward the muzzle (-Z) instead of into the camera.

const REAR_Z := 0.325
const FLASH_PAST := 0.055

static var _body: StandardMaterial3D
static var _accent: StandardMaterial3D


static func build(parent: Node3D, family: WeaponDefinition.Family) -> float:
	_clear(parent)
	var muzzle_z := REAR_Z
	match family:
		WeaponDefinition.Family.SHOTGUN:
			muzzle_z = _build_shotgun(parent)
		WeaponDefinition.Family.SNIPER:
			muzzle_z = _build_sniper(parent)
		WeaponDefinition.Family.MACHINEGUN:
			muzzle_z = _build_machinegun(parent)
		_:
			muzzle_z = _build_basic(parent)
	return muzzle_z - FLASH_PAST


static func _build_basic(parent: Node3D) -> float:
	## Original 0.18 cube, 0.65 long, centered on the weapon node.
	_add_box(parent, "Body", Vector3(0.18, 0.18, 0.65), REAR_Z)
	return REAR_Z - 0.65


static func _build_shotgun(parent: Node3D) -> float:
	## Same language, stubbier and much thicker, with a flared muzzle bell.
	var body_len := 0.42
	var bell_len := 0.20
	_add_box(parent, "Cuff", Vector3(0.28, 0.26, 0.16), REAR_Z)
	_add_box(parent, "Body", Vector3(0.30, 0.28, body_len), REAR_Z - 0.14)
	_add_box(
		parent,
		"Bell",
		Vector3(0.40, 0.38, bell_len),
		REAR_Z - 0.14 - body_len,
		_accent_mat()
	)
	return REAR_Z - 0.14 - body_len - bell_len


static func _build_sniper(parent: Node3D) -> float:
	## Thin rail that keeps a short forearm cuff so it still reads as an arm.
	var cuff_len := 0.14
	var barrel_len := 0.98
	_add_box(parent, "Cuff", Vector3(0.16, 0.16, cuff_len), REAR_Z)
	_add_box(
		parent,
		"Barrel",
		Vector3(0.095, 0.095, barrel_len),
		REAR_Z - cuff_len
	)
	_add_box(
		parent,
		"Muzzle",
		Vector3(0.11, 0.11, 0.06),
		REAR_Z - cuff_len - barrel_len,
		_accent_mat()
	)
	return REAR_Z - cuff_len - barrel_len - 0.06


static func _build_machinegun(parent: Node3D) -> float:
	## Rotary buster: forearm housing plus a ring of square barrels.
	var cuff_len := 0.16
	var house_len := 0.40
	var barrel_len := 0.34
	_add_box(parent, "Cuff", Vector3(0.20, 0.20, cuff_len), REAR_Z)
	_add_box(parent, "Housing", Vector3(0.17, 0.17, house_len), REAR_Z - cuff_len)
	## Side capacitor — Mega Buster tank, not a magazine.
	var tank := _add_box(
		parent,
		"Tank",
		Vector3(0.08, 0.14, 0.18),
		REAR_Z - cuff_len - 0.08,
		_accent_mat()
	)
	tank.position.x = 0.14
	var barrel_rear := REAR_Z - cuff_len - house_len + 0.08
	var ring := 0.085
	for i in 6:
		var angle := TAU * float(i) / 6.0
		var barrel := _add_box(
			parent,
			"Barrel_%d" % i,
			Vector3(0.06, 0.06, barrel_len),
			barrel_rear,
			_accent_mat()
		)
		barrel.position.x = cos(angle) * ring
		barrel.position.y = sin(angle) * ring
	_add_box(
		parent,
		"Core",
		Vector3(0.07, 0.07, barrel_len + 0.08),
		barrel_rear
	)
	return barrel_rear - barrel_len - 0.08


static func _add_box(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	rear_z: float,
	material: Material = null
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.position = Vector3(0.0, 0.0, rear_z - size.z * 0.5)
	mi.material_override = material if material else _body_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _clear(parent: Node3D) -> void:
	for child in parent.get_children():
		if child is MeshInstance3D:
			parent.remove_child(child)
			child.free()


static func _body_mat() -> StandardMaterial3D:
	if _body == null:
		_body = StandardMaterial3D.new()
		_body.albedo_color = Color(0.12, 0.13, 0.13, 1)
		_body.metallic = 0.75
		_body.roughness = 0.34
	return _body


static func _accent_mat() -> StandardMaterial3D:
	if _accent == null:
		_accent = StandardMaterial3D.new()
		_accent.albedo_color = Color(0.22, 0.23, 0.24, 1)
		_accent.metallic = 0.82
		_accent.roughness = 0.28
	return _accent
