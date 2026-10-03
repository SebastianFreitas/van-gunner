extends Node
## Headless facade stress shard: runs `facade stress 1 i/n` outside the smoke so shards can
## run in parallel processes. Needs `-- --smoke-sandbox [--stress-shard=i/n]`.


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.has("--smoke-sandbox"):
		print("STRESS FAILED: needs --smoke-sandbox")
		get_tree().quit(1)
		return
	var shard := "0/1"
	for arg in args:
		if arg.begins_with("--stress-shard="):
			shard = arg.trim_prefix("--stress-shard=")
	# Let the autoloads finish their _ready before the console command runs.
	await get_tree().process_frame
	# Mirrors the smoke: there the live corridor tiles already fill the light cap, so stress
	# tiles build no Light nodes. The wall lamp at x_face - LIGHT_OUT sits 5 cm inside the lane
	# box (open question for the owner, not fixed here).
	var fixtures := preload("res://scripts/travel/facades/facade_fixtures.gd")
	for i in int(fixtures.MAX_WORLD_LIGHTS):
		var light := Node.new()
		add_child(light)
		light.add_to_group(&"facade_lights")
	var result := DebugCommands.run("facade stress 1 " + shard)
	for line in result.split("\n"):
		print("STRESS: " + line)
	if result.begins_with("OK"):
		print("STRESS: done")
		get_tree().quit(0)
	else:
		print("STRESS FAILED: shard " + shard)
		get_tree().quit(1)
