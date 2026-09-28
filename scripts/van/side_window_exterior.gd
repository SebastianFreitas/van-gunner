extends RefCounted
## Adds the dark-tinted exterior pane that rides a side cargo window's sash.

const _SHADER := preload("res://scenes/van/van_window_exterior.gdshader")

static var _pane_material: ShaderMaterial


## Builds the exterior pane mesh and hangs it on `glass` (the interior pane's node), so it
## swings with the sash and hides whenever BreakableGlass hides the glass visual.
static func add_exterior_pane(
	glass: MeshInstance3D,
	walls: VanSideWall,
	wall_sign: float,
	poly: PackedVector2Array,
	x_ref: float,
	y_ref: float,
	z_ref: float,
	poly_center_y: float,
	x_shift: float
) -> MeshInstance3D:
	if glass == null or walls == null:
		return null

	var pane := MeshInstance3D.new()
	pane.name = "ExteriorPane"
	pane.layers = 1
	pane.add_to_group(&"van_exterior_layer")
	pane.mesh = walls.build_curved_pane_from_poly(
		wall_sign, poly, x_ref, y_ref, z_ref, poly_center_y, x_shift, 8
	)
	pane.material_override = pane_material()
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The window root isn't rotated about y, so the pane's local +x is already the van's
	# outward direction; wall_sign is the sign the shader needs to discard the cabin side.
	pane.set_instance_shader_parameter(&"outward_sign", wall_sign)
	glass.add_child(pane)
	return pane


## One shared material for every exterior pane.
static func pane_material() -> ShaderMaterial:
	if _pane_material == null:
		_pane_material = ShaderMaterial.new()
		_pane_material.shader = _SHADER
		_pane_material.render_priority = 1
	return _pane_material
