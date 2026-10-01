class_name IronCross
extends Node3D

## Welded iron + outside a window pane. Local XY is the glass face; +Z is outward.
## Square tubes stand off the exterior pane on posts that drop onto feet bolted to the frame ring.
## Optional side-wall curve: tubes, plate, posts and feet follow VanSideWall.

const BrokenIronCrossScene := preload("res://scenes/van/broken_iron_cross.tscn")
const IronCrossGeo := preload("res://scripts/van/iron_cross_geo.gd")

## Foot centre to foot centre along local X.
@export var span_width := 2.32
## Foot centre to foot centre along local Y.
@export var span_height := 1.324
@export var tube_size := 0.045
@export var plate_size := 0.20
## Local z of the surface the feet stand on: the side frame ring's front.
@export var mount_z := 0.03
@export var curve_segments := 14
@export var rebuild_on_ready := true

## Back face of the vertical tube: 2 cm outside the exterior pane (0.055).
const TUBE_BACK_Z := 0.075
## The horizontal tube sits this far in front of the vertical one so no two faces are coplanar.
const TUBE_H_LIFT := 0.012
## Tube edge chamfer.
const TUBE_CHAMFER := 0.006
## How far a tube runs past its foot centre, so its end hides behind the post.
const TUBE_OVERRUN := 0.01
## Centre plate thickness.
const PLATE_DEPTH := 0.022
## Post width across the tube.
const POST_ACROSS := 0.07
## Post width along the tube.
const POST_ALONG := 0.035
## How far the top post sits below its foot centre, clear of the opening return.
const POST_TOP_DROP := 0.0065
## Foot plate width across the tube.
const FOOT_ACROSS := 0.11
## Foot plate width along the tube.
const FOOT_ALONG := 0.04
## How far a foot sinks into the mounting surface.
const FOOT_SINK := 0.015
## How far a foot stands proud of the mounting surface.
const FOOT_PROUD := 0.012
## Foot corner chamfer.
const FOOT_CHAMFER := 0.008

static var _iron_mat: StandardMaterial3D = null
static var _rivet_mat: StandardMaterial3D = null

## How far the bars bow into the cabin at each damage stage, metres.
const STAGE_DENT: Array[float] = [0.0, 0.025, 0.05]
## Plate bolts popped off at each damage stage.
const STAGE_BOLTS_LOST: Array[int] = [0, 1, 2]

var _damage_stage := 0
var _built := false
var _broken := false
## When true every built mesh sits on layers 1 and 2 (D15) and joins VanLighting.GROUP_EXTERIOR_LAYER so VanLighting doesn't force it back to layer 2.
var _street_lit := false
## When set, vertical elements bend with the cargo side-wall profile.
var _curve_walls: VanSideWall = null
var _curve_mid_y := 0.0


func _ready() -> void:
	if rebuild_on_ready:
		rebuild()


## Bend the + to match a bowed side wall. mid_y is the window center in wall space.
func follow_side_wall_curve(walls: VanSideWall, mid_y: float) -> void:
	_curve_walls = walls
	_curve_mid_y = mid_y
	rebuild()


## Put the built bars on the street-lit layers (or back on the interior layer).
func set_street_lit(on: bool) -> void:
	_street_lit = on
	for n in find_children("*", "VisualInstance3D", true, false):
		var vi := n as VisualInstance3D
		if vi == null or vi is Light3D:
			continue
		if on:
			if not vi.is_in_group(VanLighting.GROUP_EXTERIOR_LAYER):
				vi.add_to_group(VanLighting.GROUP_EXTERIOR_LAYER)
			VanLighting.retarget_layers(vi, VanLighting.LAYER_STREET_AND_INTERIOR)
		else:
			if vi.is_in_group(VanLighting.GROUP_EXTERIOR_LAYER):
				vi.remove_from_group(VanLighting.GROUP_EXTERIOR_LAYER)
			VanLighting.retarget_layers(vi, VanLighting.LAYER_VAN_INTERIOR)


func _apply_street_lit(mi: MeshInstance3D) -> void:
	if not _street_lit:
		return
	mi.layers = VanLighting.LAYER_STREET_AND_INTERIOR
	mi.add_to_group(VanLighting.GROUP_EXTERIOR_LAYER)


## Swap intact bars for a randomized blown-out stub set after a window breach.
func break_bars() -> void:
	if _broken:
		return
	_broken = true
	visible = false

	var parent := get_parent()
	if parent == null:
		return

	var broken := BrokenIronCrossScene.instantiate() as BrokenIronCross
	broken.name = "BrokenIronCross"
	broken.set(&"span_width", span_width)
	broken.set(&"span_height", span_height)
	broken.set(&"tube_size", tube_size)
	broken.set(&"plate_size", plate_size)
	broken.set(&"mount_z", mount_z)
	broken.set(&"curve_segments", curve_segments)
	broken.break_seed = 0
	broken.rebuild_on_ready = false
	broken.transform = transform
	parent.add_child(broken)
	if _curve_walls != null:
		broken.follow_side_wall_curve(_curve_walls, _curve_mid_y)
	else:
		broken.rebuild()


## Restore intact bars after a repair. Removes any BrokenIronCross sibling.
func repair_bars() -> void:
	if _broken:
		var parent := get_parent()
		if parent:
			for child in parent.get_children():
				if child is BrokenIronCross:
					child.queue_free()
		_broken = false
	visible = true


## Bend the intact bars to a damage stage (0 sound, 2 nearly gone). Called by BreachPoint.
func set_damage_stage(stage: int) -> void:
	stage = clampi(stage, 0, 2)
	if stage == _damage_stage:
		return
	_damage_stage = stage
	rebuild()


func rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_built = false
	_build()


func _make_geo() -> RefCounted:
	var geo := IronCrossGeo.new(
		_curve_walls, _curve_mid_y, span_width * 0.5, span_height * 0.5
	)
	geo.on_mesh = _apply_street_lit
	geo.segments = curve_segments
	geo.dent = STAGE_DENT[_damage_stage]
	return geo


func _build() -> void:
	if _built:
		return
	_built = true

	var geo := _make_geo()
	var iron := iron_material()
	var rivet := rivet_material()
	var hw := span_width * 0.5
	var hh := span_height * 0.5
	var s := tube_size
	var zv := TUBE_BACK_Z + s * 0.5
	# In front of the vertical tube so no two tube faces are coplanar where they cross.
	var zh := zv + TUBE_H_LIFT
	geo.add_tube(self, "VerticalBar", true, hh + TUBE_OVERRUN, s, TUBE_CHAMFER, zv, iron)
	geo.add_tube(self, "HorizontalBar", false, hw + TUBE_OVERRUN, s, TUBE_CHAMFER, zh, iron)

	# Centre plate: always square to the window, at every damage stage.
	var plate_back := zh + s * 0.5 - 0.008
	var plate_front := plate_back + PLATE_DEPTH
	var plate_poly := IronCrossGeo.chamfered_rect(plate_size * 0.5, plate_size * 0.5, 0.012)
	geo.add_prism(self, "CenterPlate", plate_poly, Vector2.ZERO, plate_back, PLATE_DEPTH, iron)

	# One window always loses the same bolts: the RNG is seeded from its path.
	var rng := RandomNumberGenerator.new()
	if is_inside_tree():
		rng.seed = hash(String(name) + str(get_parent().get_path()))
	else:
		rng.seed = hash(String(name))
	var order: Array[int] = [0, 1, 2, 3]
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := order[i]
		order[i] = order[j]
		order[j] = tmp
	var lost: Array[int] = order.slice(0, STAGE_BOLTS_LOST[_damage_stage])
	var bs := plate_size * 0.5 - 0.03
	var corners: Array[Vector2] = [Vector2(bs, bs), Vector2(-bs, bs), Vector2(bs, -bs), Vector2(-bs, -bs)]
	for idx in corners.size():
		if lost.has(idx):
			continue
		geo.add_bolt(self, "PlateBolt%d" % idx, corners[idx], plate_front, rivet)

	# Each tube end is welded to a post that drops onto a foot bolted to the frame ring.
	var ends: Array = [
		["T", Vector2(0.0, hh), true], ["B", Vector2(0.0, -hh), true],
		["R", Vector2(hw, 0.0), false], ["L", Vector2(-hw, 0.0), false],
	]
	var z_back := mount_z + FOOT_PROUD - 0.004
	for end in ends:
		var sfx: String = end[0]
		var at: Vector2 = end[1]
		var vertical: bool = end[2]
		var foot_poly := IronCrossGeo.chamfered_rect(
			FOOT_ACROSS * 0.5 if vertical else FOOT_ALONG * 0.5,
			FOOT_ALONG * 0.5 if vertical else FOOT_ACROSS * 0.5,
			FOOT_CHAMFER
		)
		geo.add_prism(
			self, "Foot" + sfx, foot_poly, at, mount_z - FOOT_SINK, FOOT_SINK + FOOT_PROUD, iron
		)
		var depth := (zv if vertical else zh) - z_back
		var size := Vector3(POST_ACROSS, POST_ALONG, depth) if vertical \
			else Vector3(POST_ALONG, POST_ACROSS, depth)
		# The wall bows in toward the top, so the top post sits 6.5 mm lower to clear the reveal.
		var post_at := at + Vector2(0.0, -POST_TOP_DROP) if sfx == "T" else at
		geo.add_box(self, "Post" + sfx, size, post_at, z_back, iron)
		var across := Vector2.RIGHT if vertical else Vector2.UP
		for k in 2:
			var p := at + across * (0.038 if k == 1 else -0.038)
			geo.add_bolt(self, "FootBolt" + sfx + str(k), p, mount_z + FOOT_PROUD, rivet)


## Shared matte dark steel for every bar, plate and pad (intact and broken crosses).
static func iron_material() -> StandardMaterial3D:
	if _iron_mat == null:
		_iron_mat = StandardMaterial3D.new()
		_iron_mat.albedo_color = Color(0.07, 0.075, 0.08, 1.0)
		_iron_mat.metallic = 0.3
		_iron_mat.roughness = 0.75
	return _iron_mat


## Shared rivet steel.
static func rivet_material() -> StandardMaterial3D:
	if _rivet_mat == null:
		_rivet_mat = StandardMaterial3D.new()
		_rivet_mat.albedo_color = Color(0.16, 0.15, 0.13, 1.0)
		_rivet_mat.metallic = 0.3
		_rivet_mat.roughness = 0.7
	return _rivet_mat
