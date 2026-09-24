extends SceneTree
## Headless load check. Loads every script, scene, resource and shader under res://
## so parse errors and broken references print as SCRIPT ERROR / ERROR lines.
## Run it through `py -3 tools/check.py`; that runner does the editor import scan first
## (new assets and `.gd.uid` files) and greps both outputs for failure lines.
## Direct form: "$GODOT" --headless --path . --script res://tools/check_scripts.gd

const _EXTENSIONS: PackedStringArray = ["gd", "tscn", "tres", "gdshader"]


func _initialize() -> void:
	var paths: PackedStringArray = []
	_collect("res://", paths)
	paths.sort()
	var failed := 0
	for path in paths:
		var res: Resource = ResourceLoader.load(path)
		if res == null:
			failed += 1
			printerr("ERROR: check_scripts: failed to load %s" % path)
		elif res is Script and not (res as Script).can_instantiate():
			failed += 1
			printerr("ERROR: check_scripts: script does not compile: %s" % path)
	print("check_scripts: loaded %d files, %d failed" % [paths.size(), failed])
	quit(1 if failed > 0 else 0)


## Dot folders (.godot, .git, .claude) hold no game files and .godot would load twice.
func _collect(dir_path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		printerr("ERROR: check_scripts: cannot open %s" % dir_path)
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full := dir_path.path_join(entry)
			if dir.current_is_dir():
				_collect(full, out)
			elif entry.get_extension() in _EXTENSIONS:
				out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
