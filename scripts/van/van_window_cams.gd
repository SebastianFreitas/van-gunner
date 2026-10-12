class_name VanWindowCams
extends Node3D
## One Camera3D per van window (rig-local), standing in the cabin back from the window looking at its centre (`aim` can move it outside the van, past the bars, looking back at the window); never current by itself. "Right" and "left" are as seen from inside facing the rear doors, so right is x < 0 (the opposite of the `SideWindows` node names, which are seen facing the cab). Names: `side_<left|right>_<rear|front>`, `rear_<left|right>` (rear-door windows), `cab_<left|right>`.

const _WindowBars := preload("res://scripts/van/side_window_bars.gd")
const _LeafBuild := preload("res://scripts/van/rear_door_leaf_build.gd")
const _CrossBuild := preload("res://scripts/van/iron_cross_build.gd")

const _NEAR := 0.05
## Extra room around the window in frame, as a factor on the fitted standoff.
const _MARGIN := 1.25
## Keeps a view off the far wall and inside the cabin (m).
const _WALL_GAP := 0.1

## Camera name to its window's outward direction (rig-local), filled by `refresh`.
var _out: Dictionary = {}
## Camera name to its window's centre (rig-local), filled by `refresh`.
var _anchor: Dictionary = {}
## Camera name to the default view's position, filled by `refresh`.
var _view: Dictionary = {}
## Camera name to the distance from its window centre to the outermost bar or skin, filled by
## `refresh`.
var _reach: Dictionary = {}
## Camera name to the standoff that fits its window in the FOV, shared by the inside and outside
## views, filled by `refresh`.
var _fit: Dictionary = {}


func _ready() -> void:
	refresh()


## Rebuilds every camera's position from the van's size helpers, creating missing cameras.
func refresh() -> void:
	_out.clear()
	_anchor.clear()
	_view.clear()
	_reach.clear()
	_fit.clear()
	# The glass sits on the liner, not mid-wall like the opening box.
	var profile := VanBodyProfile.new(VanAnchors.side_walls(get_tree()))
	var glass_x := profile.inner_x_at(VanOpenings.SIDE_WINDOW_Y)
	var bar_depth: float = _WindowBars.DEPTH_M * _CrossBuild.SKIN_BAR_SCALE
	for side in [-1, 1]:
		var tag := "right" if side < 0 else "left"
		for index in 2:
			var box := VanOpenings.side_window_aabb(side, index)
			var centre := box.get_center()
			centre.x = float(side) * glass_x
			_place("side_%s_%s" % [tag, "rear" if index == 0 else "front"],
					centre, Vector3(float(side), 0.0, 0.0),
					maxf(box.size.y, box.size.z), false, _WindowBars.OUTER_M)
		var rear := VanOpenings.rear_window_aabb(side)
		var rear_centre := rear.get_center()
		# The rear glass sits at the hinge, the leaf's cabin face (CABIN_Z) off the hole's start.
		rear_centre.z =rear.position.z - _LeafBuild.CABIN_Z
		_place("rear_" + tag, rear_centre, Vector3.BACK,
				maxf(rear.size.x, rear.size.y), false, _LeafBuild.STREET_HALF + bar_depth)
		var cab_x := float(side) * (VanCab.CAB_HALF_W + VanCab.DOOR_WIN_OUT)
		_place("cab_" + tag, Vector3(cab_x, (VanCab.DOOR_WIN_BOT_Y + VanCab.DOOR_WIN_TOP_Y) * 0.5,
				(VanCab.DOOR_BACK_Z + VanCab.DOOR_FRONT_Z) * 0.5), Vector3(float(side), 0.0, 0.0),
				maxf(VanCab.DOOR_WIN_TOP_Y - VanCab.DOOR_WIN_BOT_Y,
				absf(VanCab.DOOR_BACK_Z - VanCab.DOOR_FRONT_Z)), true, 0.0)


## The camera names, sorted.
func names() -> PackedStringArray:
	var found := PackedStringArray(_out.keys())
	found.sort()
	return found


## The camera called `cam_name`, or null.
func camera(cam_name: String) -> Camera3D:
	return get_node_or_null(NodePath(cam_name)) as Camera3D


## Puts a camera back from its window on the cabin side looking at the window's centre, or at
## the window seen from outside the van, past its bars, looking back at the centre when `outward`.
func aim(cam_name: String, outward: bool) -> void:
	var cam := camera(cam_name)
	if cam == null:
		return
	var dir: Vector3 = _out[cam_name]
	var anchor: Vector3 = _anchor[cam_name]
	if outward:
		var pos := anchor + dir * (float(_reach[cam_name]) + float(_fit[cam_name]))
		cam.transform = Transform3D(Basis.looking_at(anchor - pos, Vector3.UP), pos)
	else:
		cam.transform = Transform3D(Basis.looking_at(anchor - _view[cam_name], Vector3.UP),
				_view[cam_name])


## One line: the camera's default position and the window centre it looks at.
func describe(cam_name: String) -> String:
	return "%s at %s looks at %s" % [cam_name, _view[cam_name], _anchor[cam_name]]


## `extent` is the window's larger dimension; the standoff fits it in the camera's FOV. `reach`
## is the distance from `at` out to the outermost bar or skin.
func _place(cam_name: String, at: Vector3, outward: Vector3, extent: float, in_cab: bool,
		reach: float) -> void:
	var cam := camera(cam_name)
	if cam == null:
		cam = Camera3D.new()
		cam.name = cam_name
		cam.near = _NEAR
		add_child(cam)
	var dist := extent * 0.5 / tan(deg_to_rad(cam.fov) * 0.5) * _MARGIN
	var pos := at - outward * dist
	if in_cab:
		pos.x = clampf(pos.x, -VanCab.CAB_HALF_W + _WALL_GAP, VanCab.CAB_HALF_W - _WALL_GAP)
	else:
		pos.x = clampf(pos.x, -VanInteriorSize.TOP_HALF + _WALL_GAP,
				VanInteriorSize.TOP_HALF - _WALL_GAP)
		pos.z = clampf(pos.z, VanInteriorSize.FRONT_Z + _WALL_GAP,
				VanInteriorSize.REAR_Z - _WALL_GAP)
	_out[cam_name] = outward
	_anchor[cam_name] = at
	_view[cam_name] = pos
	_reach[cam_name] = reach
	_fit[cam_name] = dist
	aim(cam_name, false)
