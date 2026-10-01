extends RefCounted
## Wall lamp fixtures and their SpotLight3D pools for one facade side: district colour, dead lamps,
## the world-wide light cap, and the layer-1 cull mask that keeps them off the van interior.


const _FacadeKeepOut := preload("res://scripts/travel/facades/facade_keep_out.gd")
const _FacadePlan := preload("res://scripts/travel/facades/facade_plan.gd")
const _FacadeMaterials := preload("res://scripts/travel/facades/facade_materials.gd")
const _FacadeMeshKit := preload("res://scripts/travel/facades/facade_mesh_kit.gd")
const _FacadeLampFlicker := preload("res://scripts/travel/facades/facade_lamp_flicker.gd")

const MAX_WORLD_LIGHTS := 12
const LIGHT_GROUP := &"facade_lights"
const LAMP_Y := 5.2
## Spot range in metres; reaches the ground from the lamp with falloff to spare.
const POOL_RANGE := 8.0
## Cone half-angle in degrees; about a 3.9 m radius pool on the ground, so the two lamps
## of a tile leave a dark gap between them.
const POOL_ANGLE := 38.0
## Multiplies district.lamp_energy (the district value stays the relative brightness
## between districts).
const POOL_ENERGY_SCALE := 8.0
## How far the light sits out from the wall face, toward the road.
const LIGHT_OUT := 1.2


## A box centred `depth` out from the face, toward the road (mirrors facade_props_ground._out_x).
static func _out_x(xf: float, ss: float, depth: float) -> float:
	return xf - ss * (_FacadeMeshKit.FACE_GAP + depth * 0.5)


## Per side: wall lamp fixtures and their downward SpotLight3D pools, capped at MAX_WORLD_LIGHTS live lights.
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
		var found := false
		for plan: Dictionary in plans:
			if z >= float(plan[&"z0"]) and z <= float(plan[&"z1"]):
				x_face = _FacadePlan.face_x(plan, side_sign)
				found = true
				break
		if not found:
			# A lamp over a gap between buildings snaps onto the nearest building's front.
			var nearest: Dictionary = {}
			var best := INF
			for plan: Dictionary in plans:
				if bool(plan.get(&"mouth", false)):
					continue
				var d := maxf(maxf(float(plan[&"z0"]) - z, z - float(plan[&"z1"])), 0.0)
				if d < best:
					best = d
					nearest = plan
			if not nearest.is_empty():
				var n0 := float(nearest[&"z0"])
				var n1 := float(nearest[&"z1"])
				z = (n0 + n1) * 0.5 if n1 - n0 < 1.2 else clampf(z, n0 + 0.6, n1 - 0.6)
				x_face = _FacadePlan.face_x(nearest, side_sign)
		var dead := force_dead or rng.randf() < district.dead_lamp_chance
		# Wreck state on its own stream, so the tile rng's draw order stays as it was.
		var lr := RandomNumberGenerator.new()
		lr.seed = hash([rng.seed, i, side_sign, &"lamp_wreck"])
		var wreck: StringName = &"steady"
		var bend := 0.0
		if dead:
			wreck = [&"droop", &"smashed", &"stub"][lr.randi_range(0, 2)]
		else:
			if lr.randf() < 0.35:
				wreck = &"flicker"
			if lr.randf() < 0.5:
				bend = lr.randf_range(0.12, 0.35)
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
		if wreck == &"flicker":
			lamp_material = lamp_material.duplicate() as StandardMaterial3D
		var arm_len := 0.45
		var cable_len := 0.0
		var head_tilt := 0.0
		match wreck:
			&"droop":
				bend = lr.randf_range(0.3, 0.6)
				cable_len = lr.randf_range(0.3, 0.6)
				head_tilt = lr.randf_range(1.1, 1.5)
			&"smashed":
				bend = lr.randf_range(0.15, 0.45)
			&"stub":
				arm_len = lr.randf_range(0.15, 0.3)
				bend = lr.randf_range(0.2, 0.7)
		var mesh := ArrayMesh.new()
		var st_bracket := SurfaceTool.new()
		st_bracket.begin(Mesh.PRIMITIVE_TRIANGLES)
		var st_head := SurfaceTool.new()
		st_head.begin(Mesh.PRIMITIVE_TRIANGLES)
		if bend > 0.0:
			# Rotate about Z, pivoting at the wall: side_sign * bend drops the outer end on both sides.
			var wall_end := Vector3(x_face, LAMP_Y, z)
			var out_vec := Vector3(-side_sign * arm_len, 0.0, 0.0)
			var arm_basis := Basis(Vector3.BACK, side_sign * bend)
			var arm_end := wall_end + arm_basis * out_vec
			var arm_xf := Transform3D(arm_basis, wall_end + arm_basis * (out_vec * 0.5))
			_FacadeMeshKit.add_box_xf_ungated(st_bracket, arm_xf, Vector3(arm_len, 0.06, 0.06))
			var head_xf := Transform3D(arm_basis, arm_end)
			if wreck == &"droop":
				_FacadeMeshKit.add_box_ungated(
					st_bracket, arm_end + Vector3(0.0, -cable_len * 0.5, 0.0),
					Vector3(0.02, cable_len, 0.02)
				)
				head_xf = Transform3D(
					Basis(Vector3.BACK, side_sign * head_tilt),
					arm_end + Vector3(0.0, -cable_len - 0.08, 0.0)
				)
			var head_box := head_size
			if wreck == &"smashed":
				head_box = Vector3(0.18, 0.08, 0.22)
			elif wreck == &"stub":
				head_box = Vector3(0.04, 0.04, 0.04)
			_FacadeMeshKit.add_box_xf_ungated(st_head, head_xf, head_box)
		else:
			_FacadeMeshKit.add_box_ungated(st_bracket, arm_center, Vector3(0.45, 0.06, 0.06))
			_FacadeMeshKit.add_box_ungated(st_head, arm_center, head_size)
		st_bracket.commit(mesh)
		mesh.surface_set_material(0, _FacadeMaterials.iron_material())
		st_head.commit(mesh)
		mesh.surface_set_material(1, lamp_material)
		var mi := MeshInstance3D.new()
		mi.name = "Fixture%d" % i
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = _FacadeMeshKit.VISIBILITY_RANGE
		host.add_child(mi)
		if dead:
			continue
		var light: SpotLight3D = null
		if (
			host.is_inside_tree()
			and host.get_tree().get_nodes_in_group(LIGHT_GROUP).size() < MAX_WORLD_LIGHTS
		):
			light = SpotLight3D.new()
			light.name = "Light%d" % i
			light.light_color = district.lamp_color
			light.light_energy = district.lamp_energy * POOL_ENERGY_SCALE
			light.spot_range = POOL_RANGE
			light.spot_angle = POOL_ANGLE
			light.spot_attenuation = 1.0
			light.spot_angle_attenuation = 2.0
			light.shadow_enabled = false
			light.light_cull_mask = 1
			light.position = Vector3(x_face - side_sign * LIGHT_OUT, LAMP_Y - 0.2, z)
			light.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
			light.add_to_group(LIGHT_GROUP)
			host.add_child(light)
		if wreck == &"flicker":
			var flicker := _FacadeLampFlicker.new()
			flicker.name = "Flicker%d" % i
			flicker.light = light
			flicker.head = lamp_material
			flicker.seed_value = lr.randi()
			host.add_child(flicker)
