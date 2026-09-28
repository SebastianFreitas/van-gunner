extends Node
## Headless probe entry scene: runs debug commands/evals/screenshots from user args and quits.
##
## Mirrors tools/smoke: the entry scene spawns a worker under the root because
## SceneRouter.go_to_van() frees the current scene, then the worker parses
## --probe-* user args, drives DebugCommands and/or takes a screenshot, and quits
## with a nonzero exit on any failure so tools/probe.py can report it.

var _done := false


func _ready() -> void:
	if get_tree().current_scene == self:
		var worker: Node = (get_script() as GDScript).new()
		worker.name = "ProbeWorker"
		get_tree().root.add_child.call_deferred(worker)
		return
	await _run()


func _run() -> void:
	var args := _parse_args()
	var timeout: float = float(args.get("probe-timeout", "120.0"))
	get_tree().create_timer(timeout).timeout.connect(func() -> void:
		if not _done:
			_fail("watchdog timeout")
	)

	if not SaveSandbox.enabled:
		_fail("save sandbox is off; run with -- --smoke-sandbox")
		return
	if not DebugConfig.ENABLED:
		_fail("DebugConfig.ENABLED is false")
		return

	var target: Node = await _get_target(args)
	if _done:
		return

	var frames: int = maxi(int(args.get("probe-frames", "10")), 0)
	for i in range(frames):
		if _done:
			return
		await get_tree().process_frame

	for line in args.get("probe-cmd", []):
		if _done:
			return
		var out: String = DebugCommands.run(line)
		print("PROBE CMD %s" % line)
		for l in out.split("\n"):
			print("  " + l)
		await get_tree().process_frame
		await get_tree().process_frame

	if _done:
		return
	if args.has("probe-eval"):
		_run_eval(String(args["probe-eval"]), target)
		if _done:
			return

	if args.has("probe-shot"):
		await _take_shots(args)
		if _done:
			return

	print("PROBE: done")
	get_tree().quit(0)


func _parse_args() -> Dictionary:
	var result: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--probe-"):
			continue
		var eq: int = arg.find("=")
		if eq < 0:
			continue
		var key: String = arg.substr(2, eq - 2)
		var value: String = arg.substr(eq + 1)
		if key == "probe-cmd":
			var list: Array = result.get(key, [])
			list.append(value)
			result[key] = list
		else:
			result[key] = value
	return result


func _get_target(args: Dictionary) -> Node:
	if args.has("probe-scene"):
		var scene_path: String = String(args["probe-scene"])
		var packed := load(scene_path) as PackedScene
		if packed == null:
			_fail("cannot load %s" % scene_path)
			return null
		var node := packed.instantiate()
		get_tree().root.add_child(node)
		print("PROBE: loaded %s" % scene_path)
		return node

	SceneRouter.go_to_van()
	if not await _wait_for_van_ready():
		return null
	print("PROBE: van ready")
	return get_tree().current_scene


func _wait_for_van_ready() -> bool:
	var elapsed := 0.0
	while elapsed < 30.0:
		if (
			get_tree().get_first_node_in_group(&"van_run")
			and get_tree().get_first_node_in_group(&"gun_stats")
			and get_tree().get_first_node_in_group(&"player")
		):
			return true
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	_fail("timed out waiting for the van scene")
	return false


func _run_eval(text: String, target: Node) -> void:
	var expr := Expression.new()
	if expr.parse(text) != OK:
		_fail("eval parse: %s" % expr.get_error_text())
		return
	var result: Variant = expr.execute([], target, true)
	if expr.has_execute_failed():
		_fail("eval: %s" % expr.get_error_text())
		return
	print("PROBE EVAL: %s" % str(result))


func _take_shots(args: Dictionary) -> void:
	var path: String = String(args["probe-shot"])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var every: float = float(args.get("probe-every", "0"))
	var max_shots: int = int(args.get("probe-max", "0"))
	if every > 0.0 and max_shots > 0:
		for i in range(max_shots):
			var file: String = "%s-%02d.png" % [path.get_basename(), i + 1]
			await _save_shot(file)
			if _done:
				return
			if i < max_shots - 1:
				await get_tree().create_timer(every).timeout
	else:
		await _save_shot(path)


func _save_shot(path: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var err := image.save_png(path)
	if err != OK:
		_fail("could not save %s (error %d)" % [path, err])
		return
	print("PROBE SHOT: %s" % path)


func _fail(msg: String) -> void:
	if _done:
		return
	_done = true
	print("PROBE ERROR: %s" % msg)
	get_tree().quit(1)
