class_name BrokenIronCross
extends Node3D

## Blown-out iron + after a window breach. Same local frame as IronCross:
## XY = glass face, +Z = outward. Centre plate and mid-tubes are gone;
## only the feet, posts and bolts stay, with bent tube stubs jutting inward from the posts.
## Optional side-wall curve: feet + posts follow VanSideWall (via IronCrossGeo).

const IronCrossGeo := preload("res://scripts/van/iron_cross_geo.gd")

@export var span_width := 2.32
@export var span_height := 1.324
@export var tube_size := 0.045
@export var plate_size := 0.20
## Back of the feet off the frame ring (the rear doors use the window lip).
@export var mount_z := 0.03
@export var curve_segments := 14
@export var rebuild_on_ready := true

## 0 = fresh RNG each rebuild. Non-zero = stable look for that seed.
@export var break_seed := 0

## Stub length as a fraction of half-span (before the blown center gap).
@export_range(0.12, 0.55, 0.01) var stub_length_min := 0.18
@export_range(0.12, 0.55, 0.01) var stub_length_max := 0.42

## Max bend toward the cabin (degrees). Long stubs get less; never near 90°.
@export_range(5.0, 50.0, 1.0) var bend_out_max_deg := 32.0

var _built := false
var _rng := RandomNumberGenerator.new()
var _curve_walls: VanSideWall = null
var _curve_mid_y := 0.0
var _geo: RefCounted = null
## Longest stub so far, for the hanging plate (null while it curls outward).
var _longest_len := 0.0
var _longest_tip: Node3D = null
## That tip's transform in this node's frame, to keep the plate in front of the foot plane.
var _longest_xf := Transform3D.IDENTITY


func _ready() -> void:
	if rebuild_on_ready:
		rebuild()


## Bend remaining feet/posts/stubs to match a bowed side wall.
func follow_side_wall_curve(walls: VanSideWall, mid_y: float) -> void:
	_curve_walls = walls
	_curve_mid_y = mid_y
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

	var iron := IronCross.iron_material()
	var rivet := IronCross.rivet_material()
	var hw := span_width * 0.5
	var hh := span_height * 0.5
	var s := tube_size
	var zv := IronCross.TUBE_BACK_Z + s * 0.5
	var zh := zv + IronCross.TUBE_H_LIFT
	_geo = IronCrossGeo.new(_curve_walls, _curve_mid_y, hw, hh)
	_geo.segments = curve_segments
	_geo.dent = 0.0
	_longest_len = 0.0
	_longest_tip = null

	# Feet and posts stay; each end is [suffix, position, vertical tube, centre z, half span].
	var ends := [
		["T", Vector2(0.0, hh), true, zv, hh],
		["B", Vector2(0.0, -hh), true, zv, hh],
		["R", Vector2(hw, 0.0), false, zh, hw],
		["L", Vector2(-hw, 0.0), false, zh, hw],
	]
	var post_back := mount_z + IronCross.FOOT_PROUD - 0.004
	for end in ends:
		var sfx: String = end[0]
		var at: Vector2 = end[1]
		var vertical: bool = end[2]
		var zc: float = end[3]
		var inward := -Vector2(signf(at.x), signf(at.y))
		var fa := IronCross.FOOT_ACROSS * 0.5
		var fl := IronCross.FOOT_ALONG * 0.5
		var foot_poly := IronCrossGeo.chamfered_rect(
			fa if vertical else fl, fl if vertical else fa, IronCross.FOOT_CHAMFER
		)
		_geo.add_prism(
			self, "Foot" + sfx, foot_poly, at, mount_z - IronCross.FOOT_SINK,
			IronCross.FOOT_SINK + IronCross.FOOT_PROUD, iron
		)
		# Caps the stub's root too, since no tube runs through the post here.
		var post_depth := zc + s * 0.5 - post_back
		var post_size := Vector3(IronCross.POST_ACROSS, IronCross.POST_ALONG, post_depth)
		if not vertical:
			post_size = Vector3(IronCross.POST_ALONG, IronCross.POST_ACROSS, post_depth)
		var post_at := at + Vector2(0.0, -IronCross.POST_TOP_DROP) if sfx == "T" else at
		_geo.add_box(self, "Post" + sfx, post_size, post_at, post_back, iron)
		for k in 2:
			var side := -1.0 if k == 0 else 1.0
			var bolt_at := at + (Vector2(side * 0.038, 0.0) if vertical else Vector2(0.0, side * 0.038))
			_geo.add_bolt(
				self, "FootBolt" + sfx + str(k), bolt_at, mount_z + IronCross.FOOT_PROUD, rivet
			)
		_add_weld_beads(at, vertical, iron)
		_add_stub(sfx, at, inward, vertical, end[4], zc, iron)
	if _longest_tip != null:
		_add_hanging_plate(_longest_tip)


## `at` is the post centre, `inward` the unit tube direction toward the window centre.
func _add_stub(
	sfx: String,
	at: Vector2,
	inward: Vector2,
	vertical: bool,
	half_span: float,
	z_centre: float,
	iron: Material
) -> void:
	var s := tube_size
	var length_t := _rng.randf_range(stub_length_min, stub_length_max)
	# Keep a clear blown-out hole; never reach the center plate zone.
	var max_reach := half_span * 0.72
	var stub_len := clampf(half_span * length_t, s * 1.2, max_reach)

	# Longer stubs stay straighter so they don't sweep into pathing space.
	var length_factor := inverse_lerp(stub_length_min, stub_length_max, length_t)
	var out_cap := minf(lerpf(bend_out_max_deg, bend_out_max_deg * 0.35, length_factor), 40.0)
	var bend := deg_to_rad(_rng.randf_range(out_cap * 0.25, out_cap))
	# Most stubs bend toward the cabin (-Z); occasional mild curl the other way.
	var curls := _rng.randf() < 0.18
	if curls:
		bend *= -0.45

	# Pivot on the post centre, bent about the axis across the tube (-Z for inward tilt).
	var wall_basis: Basis = _geo.basis_at(at.x, at.y)
	var pivot := Node3D.new()
	pivot.name = "Stub" + sfx
	pivot.position = Vector3(at.x, at.y, _geo.surface_z(at.x, at.y)) + wall_basis.z * z_centre
	var across := Vector3.RIGHT if vertical else Vector3.UP
	var bend_sign := -inward.y if vertical else inward.x
	var axis := Vector3(inward.x, inward.y, 0.0)
	pivot.basis = wall_basis
	pivot.rotate_object_local(across, bend * bend_sign)
	pivot.rotate_object_local(axis, _rng.randf_range(-0.25, 0.25))
	add_child(pivot)

	var offset_node := Node3D.new()
	offset_node.name = "StubOffset"
	offset_node.position = axis * stub_len * 0.5
	pivot.add_child(offset_node)
	# Flat geo: the stub is straight, the pivot carries the wall's orientation.
	var flat := IronCrossGeo.new(null, 0.0, 1.0, 1.0)
	flat.segments = 2
	flat.on_mesh = _geo.on_mesh
	flat.add_tube(offset_node, "Tube", vertical, stub_len * 0.5, s, IronCross.TUBE_CHAMFER, 0.0, iron)

	# Tip frame: local Y along the tube, at the tube's torn end.
	var tip := Node3D.new()
	tip.name = "Tip"
	tip.position = axis * stub_len
	tip.basis = Basis(Vector3.BACK, Vector2(0.0, 1.0).angle_to(inward))
	pivot.add_child(tip)

	# Torn end: two thin slivers splayed past the tube's end, so it reads ripped, not cut.
	for side in [-1.0, 1.0]:
		var sliver_len := _rng.randf_range(0.02, 0.05)
		var sliver := Node3D.new()
		sliver.name = "Sliver"
		# Starts 3 mm past the tube end so the faces never overlap it.
		sliver.position = Vector3(side * s * 0.25, 0.003, 0.0)
		sliver.rotate_object_local(Vector3(0.0, 0.0, 1.0), deg_to_rad(_rng.randf_range(-25.0, 25.0)))
		tip.add_child(sliver)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(s * _rng.randf_range(0.35, 0.55), sliver_len, s * 0.8)
		var mi := MeshInstance3D.new()
		mi.name = "Bit"
		mi.mesh = mesh
		mi.position = Vector3(0.0, sliver_len * 0.5, 0.0)
		mi.material_override = iron
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if _geo.on_mesh.is_valid():
			_geo.on_mesh.call(mi)
		sliver.add_child(mi)

	if stub_len > _longest_len:
		_longest_len = stub_len
		_longest_tip = null if curls else tip  # a curling longest stub means no plate
		_longest_xf = pivot.transform * tip.transform


## 2 or 3 small cubes where the post meets the foot front, half sunk, on the post's sides.
func _add_weld_beads(at: Vector2, vertical: bool, iron: Material) -> void:
	var across := Vector2.RIGHT if vertical else Vector2.UP
	var along := Vector2.UP if vertical else Vector2.RIGHT
	var base := mount_z + IronCross.FOOT_PROUD
	var count := _rng.randi_range(2, 3)
	for i in count:
		var size := _rng.randf_range(0.014, 0.022)
		var side := 1.0 if i % 2 == 0 else -1.0
		var spot := at + across * side * IronCross.POST_ACROSS * 0.5
		spot += along * _rng.randf_range(-0.3, 0.3) * IronCross.POST_ALONG
		var bead: MeshInstance3D = _geo.add_box(
			self, "WeldBead", Vector3(size, size, size), spot, base - size * 0.5, iron
		)
		bead.basis = _geo.basis_at(spot.x, spot.y) * Basis(Vector3.BACK, _rng.randf_range(0.0, TAU))


## The centre plate, torn loose: it dangles off the longest stub's tip, sagging into the cabin.
func _add_hanging_plate(stub_tip: Node3D) -> void:
	var centre_y := plate_size * 0.45
	var twist := deg_to_rad(_rng.randf_range(-20.0, 20.0))
	var tilt := deg_to_rad(_rng.randf_range(35.0, 70.0))
	# Never let the plate's lowest corner pass behind the foot plane.
	while tilt > 0.0:
		var xf := _longest_xf * Transform3D(Basis(Vector3.RIGHT, -tilt) * Basis(Vector3.BACK, twist))
		var lowest := INF
		for cx in [-1.0, 1.0]:
			for cy in [centre_y - plate_size * 0.5, centre_y + plate_size * 0.5]:
				var p: Vector3 = xf * Vector3(cx * plate_size * 0.5, cy, 0.0)
				lowest = minf(lowest, p.z - _geo.surface_z(p.x, p.y))
		if lowest >= mount_z:
			break
		tilt -= 0.05
	tilt = maxf(tilt, 0.0)
	var hinge := Node3D.new()
	hinge.name = "HangingPlate"
	hinge.rotate_object_local(Vector3.RIGHT, -tilt)
	hinge.rotate_object_local(Vector3(0.0, 0.0, 1.0), twist)
	stub_tip.add_child(hinge)
	var plate_node := Node3D.new()
	plate_node.name = "PlateOffset"
	plate_node.position = Vector3(0.0, centre_y, 0.0)
	hinge.add_child(plate_node)
	var flat := IronCrossGeo.new(null, 0.0, 1.0, 1.0)
	flat.on_mesh = _geo.on_mesh
	var half := plate_size * 0.5
	var poly := IronCrossGeo.chamfered_rect(half, half, 0.012)
	flat.add_prism(plate_node, "Plate", poly, Vector2.ZERO, 0.0, IronCross.PLATE_DEPTH, IronCross.iron_material())
	# The other two bolt holes are empty: those bolts sheared.
	for side in [-1.0, 1.0]:
		var bolt_at := Vector2(side * (half - 0.03), half - 0.03)
		flat.add_bolt(plate_node, "PlateBolt", bolt_at, IronCross.PLATE_DEPTH, IronCross.rivet_material())
