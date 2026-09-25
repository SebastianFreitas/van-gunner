extends RefCounted
## Wall lamp fixtures and their OmniLights for one facade side: district colour, dead lamps,
## the world-wide light cap, and the layer-1 cull mask that keeps them off the van interior.


const _FacadeKeepOut := preload("res://scripts/travel/facades/facade_keep_out.gd")
const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")
const _FacadeMaterials := preload("res://scripts/travel/facades/facade_materials.gd")
const _FacadeMeshKit := preload("res://scripts/travel/facades/facade_mesh_kit.gd")

const MAX_WORLD_LIGHTS := 12
const LIGHT_GROUP := &"facade_lights"
const LAMP_Y := 5.2
const LIGHT_RANGE := 9.0


## A box centred `depth` out from the face, toward the road (mirrors facade_props_ground._out_x).
static func _out_x(xf: float, ss: float, depth: float) -> float:
	return xf - ss * (_FacadeMeshKit.FACE_GAP + depth * 0.5)


## Per side: wall lamp fixtures and their OmniLight3Ds, capped at MAX_WORLD_LIGHTS live lights.
## When force_dead is true every fixture is dead and no light is added; the power_outage
## set-piece uses it.
static func build_fixtures(
	host: Node3D, plans: Array, side_sign: float, keep_out: RefCounted, rng: RandomNumberGenerator,
	district: FacadeDistrict, force_dead: bool = false
) -> void:
	if plans.is_empty():
		return
	var n := district.lamps_per_side
	var zs: Array[float] = []
	if n == 1:
		zs.append(0.0)
	elif n == 2:
		zs.append(-5.5 + rng.randf_range(-1.0, 1.0))
		zs.append(5.5 + rng.randf_range(-1.0, 1.0))
	elif n >= 3:
		var step := _FacadePlan.TILE_HALF_Z * 2.0 / float(n)
		for i in n:
			zs.append(-_FacadePlan.TILE_HALF_Z + (float(i) + 0.5) * step)
	for i in zs.size():
		var z: float = zs[i]
		var x_face := side_sign * _FacadePlan.FACE_X
		for plan: Dictionary in plans:
			if z >= float(plan[&"z0"]) and z <= float(plan[&"z1"]):
				x_face = _FacadePlan.face_x(plan, side_sign)
				break
		var dead := force_dead or rng.randf() < district.dead_lamp_chance
		# Bracket and head share the same 0.45 m protrusion: the head sits at the bracket's end.
		var arm_center := Vector3(_out_x(x_face, side_sign, 0.45), LAMP_Y, z)
		var head_size := Vector3(0.25, 0.15, 0.5)
		if not keep_out.allows(_FacadeKeepOut.box_aabb(arm_center, head_size)):
			continue
		var lamp_material: StandardMaterial3D
		if dead:
			lamp_material = _FacadeMaterials.prop_material(&"lamp_dead", Color(0.1, 0.1, 0.1), 0.7, 0.3)
		else:
			lamp_material = _FacadeMaterials.prop_material(
				StringName("lamp_" + String(district.id)), district.lamp_color * 0.35, 0.6, 0.2,
				district.lamp_color, 2.5
			)
		var mesh := ArrayMesh.new()
		var st_bracket := SurfaceTool.new()
		st_bracket.begin(Mesh.PRIMITIVE_TRIANGLES)
		_FacadeMeshKit.add_box_ungated(st_bracket, arm_center, Vector3(0.45, 0.06, 0.06))
		st_bracket.commit(mesh)
		mesh.surface_set_material(0, _FacadeMaterials.iron_material())
		var st_head := SurfaceTool.new()
		st_head.begin(Mesh.PRIMITIVE_TRIANGLES)
		_FacadeMeshKit.add_box_ungated(st_head, arm_center, head_size)
		st_head.commit(mesh)
		mesh.surface_set_material(1, lamp_material)
		var mi := MeshInstance3D.new()
		mi.name = "Fixture%d" % i
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = _FacadeMeshKit.VISIBILITY_RANGE
		host.add_child(mi)
		if dead or not host.is_inside_tree():
			continue
		if host.get_tree().get_nodes_in_group(LIGHT_GROUP).size() >= MAX_WORLD_LIGHTS:
			continue
		var light := OmniLight3D.new()
		light.name = "Light%d" % i
		light.light_color = district.lamp_color
		light.light_energy = district.lamp_energy
		light.omni_range = LIGHT_RANGE
		light.omni_attenuation = 1.5
		light.shadow_enabled = false
		light.light_cull_mask = 1
		light.position = Vector3(x_face - side_sign * 0.7, LAMP_Y - 0.2, z)
		light.add_to_group(LIGHT_GROUP)
		host.add_child(light)
