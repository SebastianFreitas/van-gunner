extends Node

## Screenshots for tools/smoke.py --shots. At each checkpoint it saves what the player
## sees, the player turned round to face the rear doors, and a camera above the cab
## looking back over the van at the street, the raiders or the stop behind it.

## Absolute folder the PNGs go to.
var dir := ""
var _count := 0


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
	var van := get_tree().get_first_node_in_group(&"van_run")
	if van == null:
		return null
	var rig := van.get_node_or_null(^"TravelPath/VanFollow/VanRig") as Node3D
	if rig == null:
		return null
	var cam := Camera3D.new()
	rig.add_child(cam)
	cam.position = Vector3(0.0, 9.0, -8.0)
	cam.rotation = Vector3(deg_to_rad(-25.0), PI, 0.0)
	return cam


func _save(label: String) -> void:
	# The frame after a change is the first one drawn with it.
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	_count += 1
	var path := dir.path_join("%02d-%s.png" % [_count, label])
	var err := image.save_png(path)
	if err != OK:
		push_error("SMOKE: could not save shot %s: %s" % [path, error_string(err)])
		return
	print("SMOKE: shot " + path)
