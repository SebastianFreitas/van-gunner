extends Node

## Screenshots for tools/smoke.py --shots. At each checkpoint it saves what the player
## sees, the player turned round to face the rear doors, and a camera above the cab
## looking back over the van at the street, the raiders or the stop behind it.
## At IDLE it also saves exterior views of the van itself, and optionally one per
## rerolled look seed (tools/smoke.py --van-seeds N).

## Absolute folder the PNGs go to.
var dir := ""
var _count := 0
## Seeds rolled for the variation shots at IDLE (tools/smoke.py --van-seeds N); 0 skips them.
var van_seeds := 0
## Van shots number themselves v01-, v02-... so the main 01-... numbering, which the
## art notes cite by number, never shifts. Keyed by prefix, so a new prefix (e.g. "c") starts
## its own 01-... run instead of continuing "v"'s count.
var _prefix_counts: Dictionary = {}

const _SideDoors := preload("res://scripts/van/side_doors.gd")
const _SideWindows := preload("res://scripts/van/side_windows.gd")
const _CloseupViews := preload("res://tools/smoke/smoke_shots_closeups.gd")
const _DebugFacadeRender := preload("res://scripts/debug/debug_facade_render_commands.gd")

## Rig-local point the van cameras look at: the van body's middle.
const _VAN_TARGET := Vector3(0.0, 1.5, 0.0)
## Rig-local camera spots; van-local -Z is the cab, the body spans x +/-2.6, y 0..3.4,
## z -4.7..4.7.
const _VAN_SIDE_FRONT := Vector3(7.0, 3.0, -10.0)
const _VAN_SIDE_REAR := Vector3(7.0, 3.0, 10.0)
const _VAN_LOW_FRONT := Vector3(0.0, 1.0, -13.0)
## Lit audit spots (debug floodlight on): three-quarters, straight on, a window close-up
## and the roof, so every face of the exterior is legible.
const _VAN_LIT_SPOTS: Array[Array] = [
	["van-lit-side-front", Vector3(7.0, 3.0, -10.0), _VAN_TARGET],
	["van-lit-side-rear", Vector3(7.0, 3.0, 10.0), _VAN_TARGET],
	["van-lit-outside", Vector3(0.0, 9.0, -8.0), _VAN_TARGET],
	["van-lit-quarter-driver", Vector3(-7.0, 2.5, -10.0), _VAN_TARGET],
	["van-lit-quarter-passenger", Vector3(7.0, 2.5, -10.0), _VAN_TARGET],
	["van-lit-front", Vector3(0.0, 1.2, -12.0), Vector3(0.0, 1.2, 0.0)],
	["van-lit-rear", Vector3(0.0, 1.5, 12.0), Vector3(0.0, 1.5, 0.0)],
	["van-lit-window", Vector3(6.0, 1.9, -1.5), Vector3(2.6, 1.9, -1.5)],
	["van-lit-roof", Vector3(0.0, 12.0, 0.5), Vector3(0.0, 3.0, 0.0)],
]
## Interior audit spots, room 4.84 m wide, 3.08 m tall, z -4.7..4.7, floor at y=0.
const _VAN_FRONT_WALL := Vector3(0.0, 1.65, 2.0)
const _VAN_FRONT_WALL_TARGET := Vector3(0.0, 1.5, -4.7)
const _VAN_DRIVER_WALL := Vector3(1.2, 1.65, -1.0)
const _VAN_DRIVER_WALL_TARGET := Vector3(-2.4, 1.5, -2.3)
const _VAN_PASSENGER_WALL := Vector3(-1.2, 1.65, -1.0)
const _VAN_PASSENGER_WALL_TARGET := Vector3(2.4, 1.5, -2.3)
const _VAN_CEILING_FRONT := Vector3(0.0, 1.4, 1.0)
const _VAN_CEILING_FRONT_TARGET := Vector3(0.0, 3.0, -4.7)
## Where the van stands on the street for the IDLE shots: the van drives at IDLE and the
## driver waits on wall-clock timers, so without a fixed spot every exterior view lands a few
## ticks further down the street each run. 12 m is behind anywhere the van can be after the
## 2 s wait and well inside `world_cull_distance`.
const _IDLE_SHOT_PROGRESS := 12.0


func shot(shot_name: String) -> void:
	# Give doors, tweens and spawns a moment to settle into what a player would see.
	await get_tree().create_timer(1.0).timeout
	await _save(shot_name + "-front")
	# The other views are for the 3D world, so the HUD and any open panel are hidden.
	var hidden := _hide_ui()
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player != null:
		# The player turns only on mouse input, so a half turn holds until undone.
		player.rotate_y(PI)
		await _save(shot_name + "-back")
		player.rotate_y(PI)
	var cam := _outside_camera()
	if cam != null:
		var previous := get_viewport().get_camera_3d()
		cam.make_current()
		await _save(shot_name + "-outside")
		if previous != null:
			previous.make_current()
		cam.queue_free()
	for layer in hidden:
		layer.visible = true


## Stops the van and its wheels (at a zero spin) and moves it to _IDLE_SHOT_PROGRESS; returns the progress to restore, or
## -1.0 when nothing was pinned (no travel controller).
func pin_van() -> float:
	var travel := get_tree().get_first_node_in_group(&"travel_controller") as TravelController
	if travel == null or travel.van_follow == null:
		return -1.0
	travel.set_physics_process(false)
	var previous := travel.van_follow.progress
	travel.van_follow.progress = _IDLE_SHOT_PROGRESS
	for wheels in _van_wheels(travel):
		wheels.set_process(false)
		for pivot in wheels.wheel_pivots:
			pivot.rotation.x = 0.0
	print("SMOKE: idle shots pin the van at %.1f m (was %.2f m)" % [_IDLE_SHOT_PROGRESS, previous])
	return previous


## Puts the van back where pin_van found it and lets it drive on.
func unpin_van(previous: float) -> void:
	if previous < 0.0:
		return
	var travel := get_tree().get_first_node_in_group(&"travel_controller") as TravelController
	if travel == null:
		return
	travel.van_follow.progress = previous
	travel.set_physics_process(true)
	for wheels in _van_wheels(travel):
		wheels.set_process(true)


## Every VanWheels under the travelling van rig (the rig is built at runtime, so look it up).
func _van_wheels(travel: TravelController) -> Array[VanWheels]:
	var found: Array[VanWheels] = []
	if travel.van_rig == null:
		return found
	for node in travel.van_rig.find_children("*", "Node3D", true, false):
		if node is VanWheels:
			found.append(node as VanWheels)
	return found


func _hide_ui() -> Array[CanvasLayer]:
	var hidden: Array[CanvasLayer] = []
	for node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var layer := node as CanvasLayer
		if layer.visible:
			layer.visible = false
			hidden.append(layer)
	return hidden


## A camera 9 m up and 8 m ahead of the cab, looking back and down over the van;
## parented to the rig so it rides along.
func _outside_camera() -> Camera3D:
	var rig := _rig()
	if rig == null:
		return null
	var cam := Camera3D.new()
	rig.add_child(cam)
	cam.position = Vector3(0.0, 9.0, -8.0)
	cam.rotation = Vector3(deg_to_rad(-25.0), PI, 0.0)
	return cam


## The van's visual rig, or null if there is no van in the tree.
func _rig() -> Node3D:
	var van := get_tree().get_first_node_in_group(&"van_run")
	if van == null:
		return null
	return van.get_node_or_null(^"TravelPath/VanFollow/VanRig") as Node3D


## Exterior views of the van itself, from outside the rig looking in; UI hidden
## throughout, like the outside checkpoint view.
func van_views(shot_name: String) -> void:
	var rig := _rig()
	if rig == null:
		return
	var hidden := _hide_ui()
	var previous := get_viewport().get_camera_3d()
	await _save_van_view(rig, _VAN_SIDE_FRONT, shot_name + "-van-side-front")
	await _save_van_view(rig, _VAN_SIDE_REAR, shot_name + "-van-side-rear")
	await _save_van_view(rig, _VAN_LOW_FRONT, shot_name + "-van-low-front")
	await _save_van_view(
		rig, _VAN_FRONT_WALL, shot_name + "-front-wall", _VAN_FRONT_WALL_TARGET
	)
	await _save_van_view(
		rig, _VAN_DRIVER_WALL, shot_name + "-driver-wall", _VAN_DRIVER_WALL_TARGET
	)
	await _save_van_view(
		rig, _VAN_PASSENGER_WALL, shot_name + "-passenger-wall", _VAN_PASSENGER_WALL_TARGET
	)
	await _save_van_view(
		rig, _VAN_CEILING_FRONT, shot_name + "-ceiling-front", _VAN_CEILING_FRONT_TARGET
	)
	if van_seeds > 0:
		var look := get_tree().get_first_node_in_group(VanLook.GROUP) as VanLook
		if look != null:
			var original := look.van_seed
			for i in van_seeds:
				var seed_value := i + 1
				look.rebuild(seed_value)
				await _save_van_view(
					rig, _VAN_SIDE_FRONT, "%s-van-seed-%d" % [shot_name, seed_value]
				)
			look.rebuild(original)
	if previous != null:
		previous.make_current()
	for layer in hidden:
		layer.visible = true


## The exterior again under the debug floodlight (`floodlight on`), then the lights go
## back off, so the unlit shots stay inside the outside brightness budget.
func van_views_lit(shot_name: String) -> void:
	var rig := _rig()
	if rig == null:
		return
	var hidden := _hide_ui()
	var previous := get_viewport().get_camera_3d()
	print("SMOKE: " + DebugCommands.run("floodlight on"))
	for spot in _VAN_LIT_SPOTS:
		await _save_van_view(rig, spot[1], "%s-%s" % [shot_name, spot[0]], spot[2])
	print("SMOKE: " + DebugCommands.run("floodlight off"))
	if previous != null:
		previous.make_current()
	for layer in hidden:
		layer.visible = true


## Close-ups of door and window seams, both doors and every window (inside and outside,
## closed and open), and the rear roof line, under the debug floodlight. Each view opens
## exactly its own doors/windows through the gameplay API and waits for the tweens to settle,
## so a door or window is never mid-tween in a shot; everything is closed again before
## returning, so this never moves the IDLE fingerprint.
func van_views_closeups() -> void:
	var rig := _rig()
	if rig == null:
		return
	var side_doors := rig.get_node_or_null(^"Interior/Shell/SideDoors")
	var side_windows := rig.get_node_or_null(^"Interior/Shell/SideWindows")
	if side_doors == null or side_windows == null:
		return
	var hidden := _hide_ui()
	var previous := get_viewport().get_camera_3d()
	print("SMOKE: " + DebugCommands.run("floodlight on"))
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	# The scripts' own tween durations, summed, plus a settle margin.
	var settle: float = (
		side_doors.recess_duration + side_doors.slide_duration
		+ side_doors.grip_retract_duration + side_doors.mount_retract_duration
		+ side_windows.open_duration + side_windows.grip_retract_duration
		+ side_windows.mount_retract_duration + 0.3
	)
	var open_doors: Array[StringName] = []
	var open_windows: Array[StringName] = []
	for view in _CloseupViews.views(rig):
		var wanted_doors: Array[StringName] = view["doors"]
		var wanted_windows: Array[StringName] = view["windows"]
		if wanted_doors != open_doors or wanted_windows != open_windows:
			for side in [_SideDoors.SIDE_LEFT, _SideDoors.SIDE_RIGHT]:
				if side in wanted_doors and not side in open_doors:
					side_doors.open_door(side)
				elif side in open_doors and not side in wanted_doors:
					side_doors.close_door(side)
			for id in _SideWindows.ALL_WINDOWS:
				if id in wanted_windows and not id in open_windows:
					side_windows.open_window(id)
				elif id in open_windows and not id in wanted_windows:
					side_windows.close_window(id)
			open_doors = wanted_doors
			open_windows = wanted_windows
			await get_tree().create_timer(settle).timeout
		var from: Vector3 = view["from"]
		if player != null and rig.to_global(from).distance_to(player.global_position) < 0.5:
			from.z -= 0.6
		await _save_van_view(rig, from, view["label"], view["target"], "c")
	for side in [_SideDoors.SIDE_LEFT, _SideDoors.SIDE_RIGHT]:
		side_doors.close_door(side)
	for id in _SideWindows.ALL_WINDOWS:
		side_windows.close_window(id)
	await get_tree().create_timer(settle).timeout
	print("SMOKE: " + DebugCommands.run("floodlight off"))
	if previous != null:
		previous.make_current()
	for layer in hidden:
		layer.visible = true


## First-person arm close-ups through the `arms` debug command, saved with the "a" prefix.
func arm_views() -> void:
	var hidden := _hide_ui()
	for view in ["front", "side", "left", "top", "elbow"]:
		DebugCommands.run("arms cam " + view)
		await _save("arms-" + view, "a")
	DebugCommands.run("arms reload 0.5")
	DebugCommands.run("arms cam front")
	await _save("arms-reload", "a")
	DebugCommands.run("arms reload off")
	DebugCommands.run("arms weave 2.9")
	DebugCommands.run("arms cam front")
	await _save("arms-weave", "a")
	DebugCommands.run("arms weave off")
	DebugCommands.run("arms cam off")
	for layer in hidden:
		layer.visible = true


## The gap-light views (g01-...): every seam of the rear and side doors and the ceiling join
## from the cabin (gaplight on) and the street (gaplight out), under the floodlight. A magenta
## pixel is a see-through gap (tools/gap_check.py counts them). Leaves both side doors closed
## and the gap light off.
func van_views_gaps() -> void:
	var rig := _rig()
	if rig == null:
		return
	var side_doors := rig.get_node_or_null(^"Interior/Shell/SideDoors")
	var side_windows := rig.get_node_or_null(^"Interior/Shell/SideWindows")
	if side_doors == null or side_windows == null:
		return
	var hidden := _hide_ui()
	var previous := get_viewport().get_camera_3d()
	print("SMOKE: " + DebugCommands.run("floodlight on"))
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	# The scripts' own tween durations, summed, plus a settle margin.
	var settle: float = (
		side_doors.recess_duration + side_doors.slide_duration
		+ side_doors.grip_retract_duration + side_doors.mount_retract_duration
		+ side_windows.open_duration + side_windows.grip_retract_duration
		+ side_windows.mount_retract_duration + 0.3
	)
	# Called once, while the doors are closed (the close-ups leave them closed).
	var views := _CloseupViews.gap_views(rig)
	if views.is_empty():
		print("SMOKE: " + DebugCommands.run("floodlight off"))
		if previous != null:
			previous.make_current()
		for layer in hidden:
			layer.visible = true
		return
	var open_doors: Array[StringName] = []
	var mode := ""
	for view in views:
		var wanted_doors: Array[StringName] = view["doors"]
		if wanted_doors != open_doors:
			for side in [_SideDoors.SIDE_LEFT, _SideDoors.SIDE_RIGHT]:
				if side in wanted_doors and not side in open_doors:
					side_doors.open_door(side)
				elif side in open_doors and not side in wanted_doors:
					side_doors.close_door(side)
			open_doors = wanted_doors
			await get_tree().create_timer(settle).timeout
		var from: Vector3 = view["from"]
		var target: Vector3 = view["target"]
		if player != null and rig.to_global(from).distance_to(player.global_position) < 0.5:
			# Straight away from the target, so a camera on a slit's axis stays on it.
			from += (from - target).normalized() * 0.6
		if view["mode"] != mode:
			mode = view["mode"]
			print("SMOKE: " + DebugCommands.run("gaplight " + mode))
		await _save_van_view(rig, from, view["label"], target, "g")
	for side in [_SideDoors.SIDE_LEFT, _SideDoors.SIDE_RIGHT]:
		side_doors.close_door(side)
	await get_tree().create_timer(settle).timeout
	print("SMOKE: " + DebugCommands.run("gaplight off"))
	print("SMOKE: " + DebugCommands.run("floodlight off"))
	if previous != null:
		previous.make_current()
	for layer in hidden:
		layer.visible = true


## Points a temporary camera at the van from a rig-local spot, saves the shot and frees it.
## Defaults to looking at the van body's middle; interior audit spots pass their own target.
## The player's mesh is hidden throughout: these cameras sit close to the player's spot
## and would otherwise show the capsule mesh in frame.
func _save_van_view(
	rig: Node3D, from: Vector3, label: String, target: Vector3 = _VAN_TARGET,
	prefix: String = "v"
) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	var hidden_meshes: Array[VisualInstance3D] = []
	if player != null:
		for node in player.find_children("*", "VisualInstance3D", true, false):
			var mesh := node as VisualInstance3D
			if mesh.visible:
				mesh.visible = false
				hidden_meshes.append(mesh)
	var cam := Camera3D.new()
	rig.add_child(cam)
	cam.transform = Transform3D(Basis.looking_at(target - from, Vector3.UP), from)
	cam.make_current()
	await _save(label, prefix)
	cam.queue_free()
	for mesh in hidden_meshes:
		mesh.visible = true


func _save(label: String, prefix: String = "") -> void:
	# The frame after a change is the first one drawn with it.
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String
	if prefix.is_empty():
		_count += 1
		path = dir.path_join("%02d-%s.png" % [_count, label])
	else:
		var count: int = _prefix_counts.get(prefix, 0) + 1
		_prefix_counts[prefix] = count
		path = dir.path_join("%s%02d-%s.png" % [prefix, count, label])
	var err := image.save_png(path)
	if err != OK:
		push_error("SMOKE: could not save shot %s: %s" % [path, error_string(err)])
		return
	print("SMOKE: shot " + path)
	print("SMOKE: " + _DebugFacadeRender.render_line(label))
