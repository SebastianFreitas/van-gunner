class_name BrokenIronCross
extends Node3D

## Blown-out iron + after a window breach. Same local frame as IronCross:
## XY = glass face, +Z = outward. Center plate and mid-bars are gone;
## only frame pads + jagged stubs remain.

@export var span_width := 2.2
@export var span_height := 1.23
@export var bar_width := 0.09
@export var bar_depth := 0.055
@export var rivet_size := 0.045
@export var end_pad_size := 0.16
@export var rebuild_on_ready := true

## 0 = fresh RNG each rebuild. Non-zero = stable look for that seed.
@export var break_seed := 0

## Stub length as a fraction of half-span (before the blown center gap).
@export_range(0.12, 0.55, 0.01) var stub_length_min := 0.18
@export_range(0.12, 0.55, 0.01) var stub_length_max := 0.42

## Max outward bend (degrees). Long stubs get less; never near 90°.
@export_range(5.0, 50.0, 1.0) var bend_out_max_deg := 32.0
@export_range(0.0, 25.0, 1.0) var bend_side_max_deg := 14.0

var _built := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if rebuild_on_ready:
		rebuild()


func rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_built = false
	_build()


func _build() -> void:
	if _built:
		return
	_built = true

	if break_seed != 0:
		_rng.seed = break_seed
	else:
		_rng.randomize()

	var iron := _iron_material()
	var rivet_mat := _rivet_material()
	var z := bar_depth * 0.5
	var pad_depth := bar_depth * 1.15
	var pad_z := pad_depth * 0.5
	var half_w := span_width * 0.5 - end_pad_size * 0.15
	var half_h := span_height * 0.5 - end_pad_size * 0.15

	# Frame mounts stay — bars snap off inward of these.
	_add_box("EndPad", Vector3(end_pad_size, end_pad_size * 0.85, pad_depth), Vector3(half_w, 0.0, pad_z), iron)
	_add_box("EndPad", Vector3(end_pad_size, end_pad_size * 0.85, pad_depth), Vector3(-half_w, 0.0, pad_z), iron)
	_add_box("EndPad", Vector3(end_pad_size * 0.85, end_pad_size, pad_depth), Vector3(0.0, half_h, pad_z), iron)
	_add_box("EndPad", Vector3(end_pad_size * 0.85, end_pad_size, pad_depth), Vector3(0.0, -half_h, pad_z), iron)

	var tip_rivet := rivet_size * 0.75
	var tip_z := pad_z + pad_depth * 0.5 + tip_rivet * 0.3
	for tip in [
		Vector3(half_w, 0.0, tip_z),
		Vector3(-half_w, 0.0, tip_z),
		Vector3(0.0, half_h, tip_z),
		Vector3(0.0, -half_h, tip_z),
	]:
		_add_box("TipRivet", Vector3(tip_rivet, tip_rivet, tip_rivet * 0.65), tip, rivet_mat)

	# Four stubs: inward from each pad, center gap left open.
	# inward = direction from frame toward window center.
	_add_stub("StubRight", Vector3(half_w, 0.0, z), Vector3(-1.0, 0.0, 0.0), half_w, iron)
	_add_stub("StubLeft", Vector3(-half_w, 0.0, z), Vector3(1.0, 0.0, 0.0), half_w, iron)
	_add_stub("StubTop", Vector3(0.0, half_h, z), Vector3(0.0, -1.0, 0.0), half_h, iron)
	_add_stub("StubBottom", Vector3(0.0, -half_h, z), Vector3(0.0, 1.0, 0.0), half_h, iron)


func _add_stub(
	node_name: String,
	anchor: Vector3,
	inward: Vector3,
	half_span: float,
	iron: Material
) -> void:
	var length_t := _rng.randf_range(stub_length_min, stub_length_max)
	# Keep a clear blown-out hole; never reach the center plate zone.
	var max_reach := half_span * 0.72
	var stub_len := clampf(half_span * length_t, bar_width * 1.2, max_reach)

	# Longer stubs stay straighter so they don't sweep into pathing space.
	var length_factor := inverse_lerp(stub_length_min, stub_length_max, length_t)
	var out_cap := lerpf(bend_out_max_deg, bend_out_max_deg * 0.35, length_factor)
	var side_cap := lerpf(bend_side_max_deg, bend_side_max_deg * 0.25, length_factor)
	# Hard ceiling well below 90° — no floor-horizontal spears.
	out_cap = minf(out_cap, 40.0)
	side_cap = minf(side_cap, 18.0)

	var bend_out := deg_to_rad(_rng.randf_range(out_cap * 0.25, out_cap))
	var bend_side := deg_to_rad(_rng.randf_range(-side_cap, side_cap))
	# Bias most stubs outward (+Z); occasional mild inward curl.
	if _rng.randf() < 0.18:
		bend_out *= -0.45

	var pivot := Node3D.new()
	pivot.name = node_name
	pivot.position = anchor
	# Local Y = along bar toward center, local Z = glass outward (+Z), X = across.
	var across := Vector3(-inward.y, inward.x, 0.0)
	if across.length_squared() < 0.001:
		across = Vector3.RIGHT
	across = across.normalized()
	var x_axis := across
	var y_axis := inward.normalized()
	var z_axis := x_axis.cross(y_axis).normalized()
	if z_axis.dot(Vector3(0.0, 0.0, 1.0)) < 0.0:
		x_axis = -x_axis
		z_axis = x_axis.cross(y_axis).normalized()
	pivot.basis = Basis(x_axis, y_axis, z_axis)
	# Right = outward bend into +Z; Forward/Z = in-plane sideways curl.
	pivot.rotate_object_local(Vector3.RIGHT, bend_out)
	pivot.rotate_object_local(Vector3(0.0, 0.0, 1.0), bend_side)
	add_child(pivot)

	# Root segment from frame toward break.
	var root_frac := _rng.randf_range(0.55, 0.78)
	var root_len := stub_len * root_frac
	var tip_len := stub_len - root_len
	_add_box_to(
		pivot,
		"Root",
		Vector3(bar_width, root_len, bar_depth),
		Vector3(0.0, root_len * 0.5, 0.0),
		iron
	)

	# Jagged tip: shorter, kinked, slightly thinned — snapped look.
	var tip := Node3D.new()
	tip.name = "Tip"
	tip.position = Vector3(0.0, root_len, 0.0)
	var kink_side := deg_to_rad(_rng.randf_range(-22.0, 22.0))
	var kink_out := deg_to_rad(_rng.randf_range(-18.0, 28.0))
	# If root was long, keep tip kink modest.
	kink_side *= lerpf(1.0, 0.4, length_factor)
	kink_out *= lerpf(1.0, 0.45, length_factor)
	tip.rotate_object_local(Vector3.RIGHT, kink_out)
	tip.rotate_object_local(Vector3(0.0, 0.0, 1.0), kink_side)
	pivot.add_child(tip)

	var tip_w := bar_width * _rng.randf_range(0.7, 1.05)
	var tip_d := bar_depth * _rng.randf_range(0.75, 1.1)
	_add_box_to(
		tip,
		"Shard",
		Vector3(tip_w, maxf(tip_len, bar_width * 0.8), tip_d),
		Vector3(0.0, maxf(tip_len, bar_width * 0.8) * 0.5, 0.0),
		iron
	)

	# Occasional tiny break flake near the snap for extra jaggedness.
	if _rng.randf() < 0.55:
		var flake_len := bar_width * _rng.randf_range(0.6, 1.3)
		var flake := Node3D.new()
		flake.name = "Flake"
		flake.position = Vector3(
			_rng.randf_range(-bar_width * 0.15, bar_width * 0.15),
			tip_len * _rng.randf_range(0.2, 0.7),
			bar_depth * _rng.randf_range(0.1, 0.35)
		)
		flake.rotate_object_local(Vector3.RIGHT, deg_to_rad(_rng.randf_range(-40.0, 40.0)))
		flake.rotate_object_local(Vector3.UP, deg_to_rad(_rng.randf_range(-35.0, 35.0)))
		tip.add_child(flake)
		_add_box_to(
			flake,
			"Bit",
			Vector3(bar_width * 0.45, flake_len, bar_depth * 0.5),
			Vector3(0.0, flake_len * 0.5, 0.0),
			iron
		)


func _add_box(node_name: String, size: Vector3, pos: Vector3, material: Material) -> void:
	_add_box_to(self, node_name, size, pos, material)


func _add_box_to(
	parent: Node,
	node_name: String,
	size: Vector3,
	pos: Vector3,
	material: Material
) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)


func _iron_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.07, 0.075, 0.08, 1.0)
	mat.metallic = 0.72
	mat.roughness = 0.48
	return mat


func _rivet_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.17, 0.15, 1.0)
	mat.metallic = 0.85
	mat.roughness = 0.35
	return mat
