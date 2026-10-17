extends RefCounted
## Debug console `arms import-diff <baked.glb>`: per part, vertex count and max position delta by index between the editor import of arms.glb, the same file through GLTFDocument and a bake.

const _SRC := "res://assets/models/arms/arms.glb"


func run(args: Array) -> String:
	if args.size() < 2:
		return "ARMS IMPORT-DIFF ERROR: usage arms import-diff <baked.glb>"
	var baked := str(args[1])
	var editor := _editor_set()
	var doc := ArmsBakeDiff.load_file(_SRC)
	var bake := ArmsBakeDiff.load_file(baked)
	for s: Dictionary in [doc, bake]:
		if s.has("error"):
			return "ARMS IMPORT-DIFF ERROR: " + str(s["error"])
	var out := "ARMS IMPORT-DIFF editor vs doc (%s) vs bake (%s)" % [_SRC, baked]
	var names := (doc["parts"] as Dictionary).keys()
	names.sort()
	for part: String in names:
		out += "\n  %s: editor-doc %s | editor-bake %s | doc-bake %s" % [part,
				_pair(editor.get(part), doc["parts"][part]),
				_pair(editor.get(part), (bake["parts"] as Dictionary).get(part)),
				_pair(doc["parts"][part], (bake["parts"] as Dictionary).get(part))]
		out += "\n  %s id check: %s" % [part,
				_id_check(editor.get(part), (bake["parts"] as Dictionary).get(part))]
	return out


## For each editor-imported vertex, the baked vertex at its CUSTOM2.w id has the same position
## (1e-5): "n=.. bad=.. maxd=..", where bad counts ids out of range or further than 1e-5.
func _id_check(ed: Variant, b: Variant) -> String:
	if ed == null or b == null:
		return "missing"
	var ea: Array = (ed as Array)[0]
	var vb: PackedVector3Array = (b as Array)[0][Mesh.ARRAY_VERTEX]
	var ve: PackedVector3Array = ea[Mesh.ARRAY_VERTEX]
	if ea[Mesh.ARRAY_CUSTOM2] == null:
		return "no CUSTOM2"
	var c2: PackedFloat32Array = ea[Mesh.ARRAY_CUSTOM2]
	var bad := 0
	var worst := 0.0
	for i in ve.size():
		var id := int(c2[i * 4 + 3])
		if id < 0 or id >= vb.size():
			bad += 1
			continue
		var d := ve[i].distance_to(vb[id])
		worst = maxf(worst, d)
		if d > 1e-5:
			bad += 1
	return "n=%d bad=%d maxd=%.7f" % [ve.size(), bad, worst]


## {part name: [surface arrays]} of the editor-imported scene, as the game loads it.
func _editor_set() -> Dictionary:
	var out := {}
	var ps := load(_SRC) as PackedScene
	if ps == null:
		return out
	var root := ps.instantiate()
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := (n as MeshInstance3D).mesh
		if mesh == null:
			continue
		var surfaces: Array = []
		for s in mesh.get_surface_count():
			surfaces.append(mesh.surface_get_arrays(s))
		out[String(n.name)] = surfaces
	root.free()
	return out


## "n=a/b maxd=x inset=k" over the first surface's vertices by index (inset: a vertices found anywhere in b at 1e-4); "missing" when a side lacks the part.
func _pair(a: Variant, b: Variant) -> String:
	if a == null or b == null:
		return "missing"
	var va: PackedVector3Array = (a as Array)[0][Mesh.ARRAY_VERTEX]
	var vb: PackedVector3Array = (b as Array)[0][Mesh.ARRAY_VERTEX]
	var worst := 0.0
	for i in mini(va.size(), vb.size()):
		worst = maxf(worst, va[i].distance_to(vb[i]))
	var keys := {}
	for v in vb:
		keys[Vector3i((v * 10000.0).round())] = true
	var same := 0
	for v in va:
		if keys.has(Vector3i((v * 10000.0).round())):
			same += 1
	return "n=%d/%d maxd=%.6f inset=%d" % [va.size(), vb.size(), worst, same]
