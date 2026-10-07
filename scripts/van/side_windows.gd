extends Node3D

## Side cargo windows — top-hinged sashes that tip vertically outward.
## Built like rear doors: wall-material bezel with a rounded cut, then dark
## frame + glass. All three pieces follow the bowed side-wall profile.

signal opened
signal closed
signal window_changed(window_id: StringName, is_open: bool)

const WIN_LEFT_REAR := &"left_rear"
const WIN_LEFT_FRONT := &"left_front"
const WIN_RIGHT_REAR := &"right_rear"
const WIN_RIGHT_FRONT := &"right_front"

const ALL_WINDOWS: Array[StringName] = [
	WIN_LEFT_REAR,
	WIN_LEFT_FRONT,
	WIN_RIGHT_REAR,
	WIN_RIGHT_FRONT,
]

## Front sashes sit next to the sliding side doors and swing into the door path.
const DOOR_ADJACENT_WINDOWS: Array[StringName] = [
	WIN_LEFT_FRONT,
	WIN_RIGHT_FRONT,
]

@export var open_angle_deg := 85.0
@export var open_duration := 0.75
@export var grip_retract_duration := 0.08
@export var mount_retract_duration := 0.1
@export var grip_retract_distance := 0.035
@export var mount_retract_distance := 0.018
## Extra outward nudge for glass + iron bars only (frame stays on the wall liner).
@export var glass_outward_bump := 0.05

## Original CSG glass sat this far into the cabin from the liner face.
const GLASS_INSET := 0.06
## IronCross origin on the liner (into_cabin 0 after glass_outward_bump): its 0.002..0.05 band
## sits between WindowGlass (-0.01) and ExteriorPane (+0.055).
const IRON_INSET := 0.05
## Original breakable collider inset (into cabin).
const BREAKABLE_INSET := 0.04
## Exterior pane stand-off from the liner: clear of the IronCross bars' outer face,
## capped so it doesn't poke past the hull skin.
const EXTERIOR_PANE_PROUD_M := 0.055

const _Fixtures := preload("res://scripts/van/side_window_fixtures.gd")

## Matches original CSG sash (half extents).
const SASH_HALF_H := 0.74

## D7: 1 cm between stacked parts.
const TRIM_LIFT := 0.01
## Reference depth off the liner (the removed hull casing's inner face); keep the frame's
## outer face TRIM_LIFT inboard of it.
const CASING_BACK_REF := 0.04
const FRAME_THICKNESS := CASING_BACK_REF - TRIM_LIFT
## The pivot sits outboard of all wall material: the hull skin's outer face is 0.22 out (panel
## 0.16 + SKIN_OFFSET_M 0.06), casing 0.13. At 0.32 the open sash stays below the cut's rounded
## top corners (y 0.519), so the frame stiles never pass through the skin's corner material. The
## strap hinges and rail (`side_window_fixtures.gd`) carry the sash at this pivot.
const HINGE_OUT_M := 0.32

## 2 cm (every edge offset inward, mitred corners) inside VanSideWall.WINDOW_CUT_POLY,
## because the van audit treats faces within 1 cm as coplanar.
var FRAME_OUTER_POLY: PackedVector2Array = PackedVector2Array([
	Vector2(-0.979, -0.687), Vector2(-1.129, -0.62), Vector2(-1.202, -0.513),
	Vector2(-1.202, 0.513), Vector2(-1.129, 0.62), Vector2(-0.979, 0.687),
	Vector2(0.979, 0.687), Vector2(1.129, 0.62), Vector2(1.202, 0.513),
	Vector2(1.202, -0.513), Vector2(1.129, -0.62), Vector2(0.979, -0.687),
])
var GLASS_POLY: PackedVector2Array = PackedVector2Array([
	Vector2(-0.861, -0.617), Vector2(-1.017, -0.56), Vector2(-1.1, -0.455),
	Vector2(-1.1, 0.455), Vector2(-1.017, 0.56), Vector2(-0.861, 0.617),
	Vector2(0.861, 0.617), Vector2(1.017, 0.56), Vector2(1.1, 0.455),
	Vector2(1.1, -0.455), Vector2(1.017, -0.56), Vector2(0.861, -0.617),
])
## How far the panes reach past the frame ring's inner edge (GLASS_POLY), under the frame, so
## no oblique ray slips between a pane's edge and the frame.
const PANE_OVERLAP_M := 0.02
## GLASS_POLY grown by PANE_OVERLAP_M (set in _ready, winding matched): both panes' outline.
var PANE_POLY: PackedVector2Array = PackedVector2Array()

var _hinges: Dictionary = {}
var _grips: Dictionary = {}
var _mounts: Dictionary = {}
var _grip_closed: Dictionary = {}
var _mount_closed: Dictionary = {}
var _open: Dictionary = {}
var _tweens: Dictionary = {}
## Vector2i(wall sign, window index) -> rolled glazing; filled by the kit fit.
var _glazing: Dictionary = {}


func _ready() -> void:
	PANE_POLY = Geometry2D.offset_polygon(GLASS_POLY, PANE_OVERLAP_M, Geometry2D.JOIN_MITER)[0]
	if Geometry2D.is_polygon_clockwise(PANE_POLY) != Geometry2D.is_polygon_clockwise(GLASS_POLY):
		PANE_POLY.reverse()
	_fit_to_side_walls()
	_bind_window(WIN_LEFT_REAR, "LeftRear")
	_bind_window(WIN_LEFT_FRONT, "LeftFront")
	_bind_window(WIN_RIGHT_REAR, "RightRear")
	_bind_window(WIN_RIGHT_FRONT, "RightFront")
	_connect_side_doors.call_deferred()


func _connect_side_doors() -> void:
	var doors := get_tree().get_first_node_in_group(&"side_doors")
	if doors != null and doors.has_signal(&"door_changed"):
		doors.door_changed.connect(_on_side_door_changed)


func _on_side_door_changed(side: StringName, is_open: bool) -> void:
	set_front_hinges_visible(side, not is_open)


func _fit_to_side_walls() -> void:
	var walls := get_parent().get_node_or_null("SideWalls") as VanSideWall
	if walls == null:
		return
	var fit := SideWindowFit.new(self)
	var wins: Array = [
		[$LeftRear, -1.0, 0], [$LeftFront, -1.0, 1], [$RightRear, 1.0, 0], [$RightFront, 1.0, 1],
	]
	for w in wins:
		var cz: float = walls.window_centers_z[w[2] as int]
		var hole := walls.cut_poly_for(w[1] as float, cz)
		var glazing: StringName = _glazing.get(Vector2i(int(w[1] as float), w[2] as int), &"")
		fit.fit(w[0] as Node3D, w[1] as float, cz, walls, hole, glazing)


## Rolled glazing, Vector2i(wall sign, window index) -> &"glass" or &"plexi".
func set_glazing(by_window: Dictionary) -> void:
	_glazing = by_window


## Re-runs the fit for all four windows after the side walls rebuild. Open sashes keep their
## angle, shattered panes stay shattered, front hinge hardware follows its door.
func refit() -> void:
	_fit_to_side_walls()
	for id in ALL_WINDOWS:
		if is_window_open(id) and _hinges.has(id):
			(_hinges[id] as Node3D).rotation.z = _open_rotation_z(id)
	var doors := get_tree().get_first_node_in_group(&"side_doors")
	for side in [&"left", &"right"]:
		set_front_hinges_visible(side, doors == null or not doors.is_door_open(side))


func is_window_open(window_id: StringName) -> bool:
	return bool(_open.get(window_id, false))


func get_window_prompt(window_id: StringName) -> String:
	if is_blocked_by_door(window_id):
		return "CLOSE DOOR FIRST"
	if is_window_open(window_id):
		return "E  CLOSE WINDOW"
	return "E  OPEN WINDOW"


func toggle_window(window_id: StringName) -> void:
	if is_window_open(window_id):
		close_window(window_id)
	else:
		open_window(window_id)


func open_window(window_id: StringName) -> void:
	if not _hinges.has(window_id) or is_window_open(window_id):
		return
	if is_blocked_by_door(window_id):
		return
	var was_any_open := _any_open()
	_open[window_id] = true
	_animate_window(window_id, true)
	window_changed.emit(window_id, true)
	if not was_any_open:
		opened.emit()


func close_window(window_id: StringName) -> void:
	if not _hinges.has(window_id) or not is_window_open(window_id):
		return
	_open[window_id] = false
	_animate_window(window_id, false)
	var tween: Tween = _tweens.get(window_id)
	if tween:
		await tween.finished
	if not is_window_open(window_id):
		window_changed.emit(window_id, false)
		if not _any_open():
			closed.emit()


func open() -> void:
	for id in ALL_WINDOWS:
		open_window(id)


func close() -> void:
	for id in ALL_WINDOWS:
		close_window(id)


func _bind_window(window_id: StringName, node_name: String) -> void:
	var root := get_node_or_null(node_name)
	if root == null:
		return
	var hinge := root.get_node_or_null("Hinge") as Node3D
	var grip := root.get_node_or_null("Hinge/Handle/Grip") as Node3D
	var mount := root.get_node_or_null("Hinge/Handle/Mount") as Node3D
	if hinge == null or grip == null or mount == null:
		push_warning("SideWindows: missing hinge/handle under %s" % node_name)
		return
	_hinges[window_id] = hinge
	_grips[window_id] = grip
	_mounts[window_id] = mount
	_grip_closed[window_id] = grip.position
	_mount_closed[window_id] = mount.position
	_open[window_id] = false


func _any_open() -> bool:
	for id in ALL_WINDOWS:
		if is_window_open(id):
			return true
	return false


func _is_left(window_id: StringName) -> bool:
	return window_id == WIN_LEFT_REAR or window_id == WIN_LEFT_FRONT


func is_door_adjacent_window(window_id: StringName) -> bool:
	return window_id in DOOR_ADJACENT_WINDOWS


func is_blocked_by_door(window_id: StringName) -> bool:
	if not is_door_adjacent_window(window_id):
		return false
	var doors := get_tree().get_first_node_in_group(&"side_doors")
	if doors == null:
		return false
	var side := &"left" if _is_left(window_id) else &"right"
	return doors.is_door_open(side)


## Shows or hides the outside hinge hardware of `side`'s front window (`&"left"`/`&"right"`):
## hidden while that side's sliding door is open, since the open leaf parks over it.
func set_front_hinges_visible(side: StringName, on: bool) -> void:
	_Fixtures.set_hinges_visible(get_node_or_null("LeftFront" if side == &"left" else "RightFront"), on)


func _into_sash_axis(window_id: StringName) -> Vector3:
	# Interior handle pulls into the sash thickness (toward the glass / outside).
	return Vector3.LEFT if _is_left(window_id) else Vector3.RIGHT


func _open_rotation_z(window_id: StringName) -> float:
	var angle := deg_to_rad(open_angle_deg)
	# Top hinge: tip bottom of sash outward (±X).
	return -angle if _is_left(window_id) else angle


func _animate_window(window_id: StringName, opening: bool) -> void:
	var hinge: Node3D = _hinges[window_id]
	var grip: Node3D = _grips[window_id]
	var mount: Node3D = _mounts[window_id]
	var grip_closed: Vector3 = _grip_closed[window_id]
	var mount_closed: Vector3 = _mount_closed[window_id]
	var into_sash := _into_sash_axis(window_id)
	var grip_retracted := grip_closed + into_sash * grip_retract_distance
	var mount_retracted := mount_closed + into_sash * mount_retract_distance
	var target_z := _open_rotation_z(window_id) if opening else 0.0

	var existing: Tween = _tweens.get(window_id)
	if existing:
		existing.kill()

	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	_tweens[window_id] = tween

	if opening:
		tween.tween_property(grip, "position", grip_retracted, grip_retract_duration)
		tween.tween_property(mount, "position", mount_retracted, mount_retract_duration)
		tween.tween_property(hinge, "rotation:z", target_z, open_duration)
	else:
		tween.tween_property(hinge, "rotation:z", target_z, open_duration)
		tween.tween_property(mount, "position", mount_closed, mount_retract_duration)
		tween.tween_property(grip, "position", grip_closed, grip_retract_duration)
