extends RefCounted
## The `wcam` view set of tools/smoke.py --shots DIR --views wcam: one inside and one `_out` shot per window camera.

var _shots: Node


func _init(shots: Node) -> void:
	_shots = shots


## Saves `wcam_<name>.png` and `wcam_<name>_out.png` for every camera the live `VanWindowCams`
## lists, then puts each camera back on its inside view.
func run() -> void:
	var rig := VanAnchors.rig(_shots.get_tree())
	var cams: VanWindowCams = null
	if rig != null:
		for child in rig.get_children():
			if child is VanWindowCams:
				cams = child
	if cams == null:
		push_error("SMOKE: no VanWindowCams in the van rig")
		return
	var hidden: Array[CanvasLayer] = _shots._hide_ui()
	var previous := _shots.get_viewport().get_camera_3d()
	# The cameras stand where the player does, so the player's own meshes stay out of frame.
	var player := _shots.get_tree().get_first_node_in_group(&"player") as Node3D
	var hidden_meshes: Array[VisualInstance3D] = []
	if player != null:
		for node in player.find_children("*", "VisualInstance3D", true, false):
			var mesh := node as VisualInstance3D
			if mesh.visible:
				mesh.visible = false
				hidden_meshes.append(mesh)
	for cam_name in cams.names():
		var cam := cams.camera(cam_name)
		cam.make_current()
		for outward in [false, true]:
			cams.aim(cam_name, outward)
			await _save("wcam_" + cam_name + ("_out" if outward else ""))
		cams.aim(cam_name, false)
	if previous != null:
		previous.make_current()
	for mesh in hidden_meshes:
		mesh.visible = true
	for layer in hidden:
		layer.visible = true


## The plain name (no running number) so the file is easy to find; same frame waits as `_save`.
func _save(label: String) -> void:
	await _shots.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = _shots.get_viewport().get_texture().get_image()
	var path: String = String(_shots.dir).path_join(label + ".png")
	var err := image.save_png(path)
	if err != OK:
		push_error("SMOKE: could not save shot %s: %s" % [path, error_string(err)])
		return
	print("SMOKE: shot " + path)
