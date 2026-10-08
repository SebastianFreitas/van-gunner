class_name IronCross
extends Node3D

## Scrap rebar + outside a window pane: two bent bars, often one in a pipe sleeve, welded and lashed.
## Local XY is the glass face; +Z is outward. Meshes come from IronCrossBuild and follow VanSideWall.

const BrokenIronCrossScene := preload("res://scenes/van/broken_iron_cross.tscn")
const IronCrossGeo := preload("res://scripts/van/iron_cross_geo.gd")
const IronCrossBuild := preload("res://scripts/van/iron_cross_build.gd")

## Hook: bend over the frame ring's outer edge (side windows, which swing open).
## Skin: step off the lip and weld onto the door skin (rear doors).
@export_enum("Hook", "Skin") var end_style := 0
## Outer edge of what the ends stand on.
@export var frame_half := Vector2(1.202, 0.687)
## The bar stays in its straight plane inside this; just past the pane edge.
@export var clear_half := Vector2(1.125, 0.642)
## Skin ends only: the door skin's z and how far the bar runs along it.
@export var skin_z := 0.05
@export var skin_reach := Vector2(1.12, 0.90)
## Local z of the surface the ends stand on: the side frame ring's front.
@export var mount_z := 0.03
## Rear-door bars: height of the welded posts that lift the skin runs off the face (0 = none).
@export var standoff := 0.0
@export var curve_segments := 14
@export var rebuild_on_ready := true

## Back of the vertical bar's plane: 2 cm outside the exterior pane (0.055).
const BAR_BACK_Z := 0.075
## Rebar radii; the two bars take two different ones.
const REBAR_RADII: Array[float] = [0.010, 0.0125, 0.016]
## Distance between rebar ribs.
const RIB_STEP := 0.05
## A bar end's hammered-thin radius, so it fits the 2 cm gap behind the ring edge.
const HOOK_RADIUS := IronCrossBuild.HOOK_RADIUS
const PIPE_RADIUS := 0.024
const WIRE_RADIUS := 0.0025

static var _iron_mat: StandardMaterial3D = null
static var _rivet_mat: StandardMaterial3D = null
static var _rebar_mat: StandardMaterial3D = null
static var _weld_mat: StandardMaterial3D = null
static var _wire_mat: StandardMaterial3D = null
static var _pipe_mat: StandardMaterial3D = null

## How far the bars bow into the cabin at each damage stage, metres.
const STAGE_DENT: Array[float] = [0.0, 0.025, 0.05]
## End welds knocked off at each damage stage.
const STAGE_WELDS_LOST: Array[int] = [0, 2, 4]

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
	broken.set(&"end_style", end_style)
	broken.set(&"frame_half", frame_half)
	broken.set(&"clear_half", clear_half)
	broken.set(&"skin_z", skin_z)
	broken.set(&"skin_reach", skin_reach)
	broken.set(&"mount_z", mount_z)
	broken.set(&"standoff", standoff)
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
	var geo := IronCrossGeo.new(_curve_walls, _curve_mid_y, frame_half.x, frame_half.y)
	geo.on_mesh = _apply_street_lit
	geo.segments = curve_segments
	geo.dent = STAGE_DENT[_damage_stage]
	return geo


func _build() -> void:
	if _built:
		return
	_built = true
	var geo := _make_geo()
	IronCrossBuild.new(self).build(geo, _rng(), _damage_stage)


## One rng per window, drawn in a fixed order so it looks the same each rebuild.
func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	if not is_inside_tree():
		rng.seed = hash(String(name))
		return rng
	var look := get_tree().get_first_node_in_group(VanLook.GROUP) as VanLook
	if look != null:
		if not look.look_rebuilt.is_connected(_on_look_rebuilt):
			look.look_rebuilt.connect(_on_look_rebuilt)
		return look.rng_for(StringName("iron_cross:" + str(get_parent().get_path())))
	rng.seed = hash(String(name) + str(get_parent().get_path()))
	return rng


func _on_look_rebuilt(_seed_value: int) -> void:
	rebuild()


## Rusty rebar.
static func rebar_material() -> StandardMaterial3D:
	if _rebar_mat == null:
		_rebar_mat = StandardMaterial3D.new()
		_rebar_mat.albedo_color = Color(0.15, 0.085, 0.05, 1.0)
		_rebar_mat.metallic = 0.15
		_rebar_mat.roughness = 0.9
	return _rebar_mat


## Dark weld blobs.
static func weld_material() -> StandardMaterial3D:
	if _weld_mat == null:
		_weld_mat = StandardMaterial3D.new()
		_weld_mat.albedo_color = Color(0.11, 0.11, 0.12, 1.0)
		_weld_mat.metallic = 0.4
		_weld_mat.roughness = 0.55
	return _weld_mat


## Galvanized lashing wire.
static func wire_material() -> StandardMaterial3D:
	if _wire_mat == null:
		_wire_mat = StandardMaterial3D.new()
		_wire_mat.albedo_color = Color(0.22, 0.22, 0.21, 1.0)
		_wire_mat.metallic = 0.5
		_wire_mat.roughness = 0.45
	return _wire_mat


## Old painted pipe sleeve.
static func pipe_material() -> StandardMaterial3D:
	if _pipe_mat == null:
		_pipe_mat = StandardMaterial3D.new()
		_pipe_mat.albedo_color = Color(0.09, 0.10, 0.08, 1.0)
		_pipe_mat.metallic = 0.2
		_pipe_mat.roughness = 0.85
	return _pipe_mat


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
