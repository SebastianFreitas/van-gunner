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
## art notes cite by number, never shifts.
var _van_count := 0

## Rig-local point the van cameras look at: the van body's middle.
const _VAN_TARGET := Vector3(0.0, 1.5, 0.0)
## Rig-local camera spots; van-local -Z is the cab, the body spans x +/-2.6, y 0..3.4,
## z -4.7..4.7.
const _VAN_SIDE_FRONT := Vector3(7.0, 3.0, -10.0)
const _VAN_SIDE_REAR := Vector3(7.0, 3.0, 10.0)
const _VAN_LOW_FRONT := Vector3(0.0, 1.0, -13.0)


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


## Points a temporary camera at the van from a rig-local spot, saves the shot and frees it.
func _save_van_view(rig: Node3D, from: Vector3, label: String) -> void:
	var cam := Camera3D.new()
	rig.add_child(cam)
	cam.transform = Transform3D(Basis.looking_at(_VAN_TARGET - from, Vector3.UP), from)
	cam.make_current()
	await _save(label, "v")
	cam.queue_free()


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
		_van_count += 1
		path = dir.path_join("%s%02d-%s.png" % [prefix, _van_count, label])
	var err := image.save_png(path)
	if err != OK:
		push_error("SMOKE: could not save shot %s: %s" % [path, error_string(err)])
		return
	print("SMOKE: shot " + path)
