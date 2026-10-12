class_name ArmSkinLayers
extends RefCounted
## Seeds one arm's skin-layer shader uniforms: the van-name tattoo, and the fixed scars, wounds,
## knuckle grazes and dirt of `ArmSkinFixed`.

## Flip a component to -1 if the tattoo reads mirrored (x) or upside down (y) in the arms-left shot.
const TAT_READ := Vector2(1, 1)
const SECTORS := 12
## Array sizes of the shader's uniforms.
const SCAR_MAX := 8
const WOUND_MAX := 4
const KNUCKLE_MAX := 4
## Dirt amount per arm.
const DIRT_L := 0.84081507
const DIRT_R := 0.76136184


## All positions are rest (mesh) space, never posed, so the layers follow the skinned mesh.
## `side` is ".L" or ".R"; `mat` is already this arm's own duplicate.
static func apply(mat: ShaderMaterial, model: Node3D, side: String, van_name: String,
		tattoo: bool) -> void:
	var sk := ArmRig.skeleton(model)
	var mi := _arm_mesh(sk)
	if mi == null:
		push_warning("ArmSkinLayers: no arm mesh under the skeleton")
		return
	var has_tattoo := false
	if tattoo and not van_name.strip_edges().is_empty():
		has_tattoo = _tattoo(mat, model, mi, sk, side, van_name)
	if not has_tattoo:
		mat.set_shader_parameter(&"tat_count", 0)
	var left := side == ".L"
	_fixed(mat, &"scar_a", _pick(ArmSkinFixed.SCAR_A_L, ArmSkinFixed.SCAR_A_R, left), SCAR_MAX)
	_fixed(mat, &"scar_b", _pick(ArmSkinFixed.SCAR_B_L, ArmSkinFixed.SCAR_B_R, left), SCAR_MAX)
	mat.set_shader_parameter(&"scar_count",
			ArmSkinFixed.SCAR_COUNT_L if left else ArmSkinFixed.SCAR_COUNT_R)
	_fixed(mat, &"wound_p", _pick(ArmSkinFixed.WOUND_P_L, ArmSkinFixed.WOUND_P_R, left), WOUND_MAX)
	_fixed(mat, &"wound_d", _pick(ArmSkinFixed.WOUND_D_L, ArmSkinFixed.WOUND_D_R, left), WOUND_MAX)
	mat.set_shader_parameter(&"wound_count",
			ArmSkinFixed.WOUND_COUNT_L if left else ArmSkinFixed.WOUND_COUNT_R)
	_fixed(mat, &"knuckles", _pick(ArmSkinFixed.KNUCKLES_L, ArmSkinFixed.KNUCKLES_R, left),
			KNUCKLE_MAX)
	mat.set_shader_parameter(&"knuckle_count",
			ArmSkinFixed.KNUCKLE_COUNT_L if left else ArmSkinFixed.KNUCKLE_COUNT_R)
	ArmSkinFolds.apply(mat, mi, sk, side)
	# Fixed per arm (the values the hand look seed drew), not rolled: the hands are one design.
	mat.set_shader_parameter(&"dirt_amount", DIRT_L if left else DIRT_R)
	# Shoulder-to-hand distance: the grease layer fades the forearm streaks by axis / span.
	var up := ArmSkinMesh.ring_frame(mi, sk, StringName("DEF-upper_arm" + side), 0.0).origin
	var hd := ArmSkinMesh.ring_frame(mi, sk, StringName("DEF-hand" + side), 0.0).origin
	mat.set_shader_parameter(&"grease_span", maxf(up.distance_to(hd), 0.001))


## The left or right fixed table as a packed array (the tables are constant `Array` literals).
static func _pick(l: Array, r: Array, left: bool) -> PackedFloat32Array:
	return PackedFloat32Array(l if left else r)


## Sets a uniform array from the flat live entries (four floats each) of a fixed table, padded.
## `size` is the shader array length.
static func _fixed(mat: ShaderMaterial, uniform: StringName, live: PackedFloat32Array,
		size: int) -> void:
	var out := PackedVector4Array()
	for i in range(0, live.size(), 4):
		out.append(Vector4(live[i], live[i + 1], live[i + 2], live[i + 3]))
	out.resize(size)
	mat.set_shader_parameter(uniform, out)


## The tattoo on the lower forearm, toward the wrist, where the player camera sees it. True when
## it was set.
static func _tattoo(mat: ShaderMaterial, model: Node3D, mi: MeshInstance3D, sk: Skeleton3D,
		side: String, van_name: String) -> bool:
	var fore := "DEF-forearm" + side
	var low := fore + ".001"
	if not _has(mi, sk, fore) or not _has(mi, sk, low):
		return false
	var frame := ArmSkinMesh.ring_frame(mi, sk, fore, 0.80)
	var p0 := frame.origin
	var span := ArmSkinMesh.ring_frame(mi, sk, low, 0.65).origin - p0
	var width := span.length()
	if width < 0.0001:
		return false
	var axis := span / width
	var height := 1.5 * _radius(mi, sk, fore, 0.5)
	var lay := ArmTattooFont.layout(van_name, width * 0.92, height)
	var unit: float = lay["unit"]
	if unit <= 0.0:
		return false
	var segs: PackedVector4Array = lay["segs"]
	for i in segs.size():
		var j := PackedFloat32Array(ArmSkinFixed.TAT_JITTER)
		var amount := 0.15 * unit
		var s := segs[i] + Vector4(j[4 * i], j[4 * i + 1], j[4 * i + 2], j[4 * i + 3]) * amount
		var x0 := s.x + 0.04 * width
		var x1 := s.z + 0.04 * width
		var y0 := s.y
		var y1 := s.w
		if TAT_READ.x < 0.0:
			x0 = width - x0
			x1 = width - x1
		if TAT_READ.y < 0.0:
			y0 = height - y0
			y1 = height - y1
		segs[i] = Vector4(x0, y0, x1, y1)
	var count := segs.size()
	segs.resize(ArmTattooFont.MAX_SEGS)
	var bx := frame.basis.x
	# Plus PI: the ink sits on the inner (palm side) forearm, hidden in the normal holding pose.
	var angle := ArmSkinMesh.facing_angle(model, fore, 1.0) + PI
	mat.set_shader_parameter(&"tat_count", count)
	mat.set_shader_parameter(&"tat_segs", segs)
	mat.set_shader_parameter(&"tat_origin", p0)
	mat.set_shader_parameter(&"tat_axis", axis)
	mat.set_shader_parameter(&"tat_ref", (bx - axis * bx.dot(axis)).normalized())
	mat.set_shader_parameter(&"tat_radius", _radius(mi, sk, fore, 1.0))
	mat.set_shader_parameter(&"tat_angle", angle)
	mat.set_shader_parameter(&"tat_along0", 0.0)
	mat.set_shader_parameter(&"tat_width", width)
	mat.set_shader_parameter(&"tat_height", height)
	mat.set_shader_parameter(&"tat_stroke", 0.32 * unit)
	return true


## Mean section radius of `bone` at fraction t: the scale every size here is a fraction of.
static func _radius(mi: MeshInstance3D, sk: Skeleton3D, bone: String, t: float) -> float:
	return ArmWrap.mean_radius(ArmWrap.section(mi, sk, bone, t, SECTORS, PackedStringArray()))


static func _has(mi: MeshInstance3D, sk: Skeleton3D, bone: String) -> bool:
	if ArmWrap.bind_index(mi, sk, bone) != -1:
		return true
	push_warning("ArmSkinLayers: bone %s missing, skipping its item" % bone)
	return false


## The bare arm mesh: the skeleton's first MeshInstance3D that is not a dress piece.
static func _arm_mesh(sk: Skeleton3D) -> MeshInstance3D:
	if sk == null:
		return null
	for c in sk.get_children():
		var nm := String(c.name)
		if c is MeshInstance3D and not nm.begins_with("Dress_"):
			return c as MeshInstance3D
	return null
