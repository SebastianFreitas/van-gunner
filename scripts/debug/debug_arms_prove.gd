extends RefCounted
## Debug console `arms prove <scratch.glb> <scratch.json>`: per vertex id, the rest-pose move between the game's arms.glb and a scratch glb from `arms.py prove`, against the asked offset.

const _SRC := "res://assets/models/arms/arms.glb"
const MOVED_TOL := 0.0002
const UNMOVED_TOL := 0.0001


func run(args: Array) -> String:
	if args.size() < 3:
		return "ARMS PROVE ERROR: usage arms prove <scratch.glb> <scratch.json>"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(args[2])))
	if not parsed is Dictionary:
		return "ARMS PROVE ERROR: cannot read " + str(args[2])
	var meta: Dictionary = parsed
	var scratch := ArmsBakeDiff.load_file(str(args[1]))
	if scratch.has("error"):
		return "ARMS PROVE ERROR: " + str(scratch["error"])
	var base := _editor_positions()
	var asked_a: Array = meta["offset"]
	var asked := Vector3(asked_a[0], asked_a[1], asked_a[2])
	var moved := {}
	for id in meta["ids"]:
		moved[int(id)] = true
	var out := "PROVE asked offset (%.5f, %.5f, %.5f) length %.5f on %s, %d vertices" % [
			asked.x, asked.y, asked.z, asked.length(), meta["part"], moved.size()]
	var worst_err := 0.0
	var worst_drift := 0.0
	var parts := (scratch["parts"] as Dictionary).keys()
	parts.sort()
	var reasons: Array[String] = []
	var named := str(meta["part"])
	for want: String in [named, "R_skin"]:
		if not parts.has(want):
			reasons.append("edited part %s not found in the scratch import" % want)
		if not base.has(want):
			reasons.append("edited part %s not found in the game's arms.glb" % want)
	var measured := 0
	for part: String in parts:
		if not base.has(part):
			out += "\n  part %s: missing in the game's arms.glb" % part
			reasons.append("part %s missing in the game's arms.glb" % part)
			continue
		var b: Dictionary = base[part]
		var sv := _by_id((scratch["parts"][part] as Array)[0])
		var mean := Vector3.ZERO
		var n := 0
		var err := 0.0
		var drift := 0.0
		var missing := 0
		for id: int in b:
			if not sv.has(id):
				missing += 1
				continue
			var d: Vector3 = sv[id] - b[id]
			if part == meta["part"] and moved.has(id):
				mean += d
				n += 1
				err = maxf(err, d.distance_to(asked))
			else:
				drift = maxf(drift, d.length())
		worst_drift = maxf(worst_drift, drift)
		worst_err = maxf(worst_err, err)
		measured += n
		if missing > 0:
			reasons.append("part %s: %d ids missing from the scratch import" % [part, missing])
		if n > 0:
			out += "\n  group %s moved: n=%d asked %s measured mean %s max error %.6f" % [
					part, n, asked, mean / n, err]
		out += "\n  part %s unmoved: ids=%d missing=%d max drift %.7f" % [
				part, b.size() - n, missing, drift]
	if measured < moved.size():
		reasons.append("measured %d moved verts, json names %d" % [measured, moved.size()])
	if worst_err > MOVED_TOL or worst_drift >= UNMOVED_TOL:
		reasons.append("error or drift over tolerance")
	out += "\n  group all: n=%d max moved error %.6f (tol %.4f), max unmoved drift %.7f (tol %.4f)" % [
			measured, worst_err, MOVED_TOL, worst_drift, UNMOVED_TOL]
	if not reasons.is_empty():
		return out + "\nPROVE FAIL: " + "; ".join(reasons)
	return out + "\nPROVE OK"


## {vertex id: position} of a surface's arrays; the id is CUSTOM2.w, else the index.
func _by_id(arrays: Array) -> Dictionary:
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var c2: Variant = arrays[Mesh.ARRAY_CUSTOM2]
	var out := {}
	for i in v.size():
		var id := i if c2 == null else int((c2 as PackedFloat32Array)[i * 4 + 3])
		out[id] = v[i]
	return out


## {part name: {id: position}} of the editor-imported arms.glb, as the game loads it.
func _editor_positions() -> Dictionary:
	var out := {}
	var ps := load(_SRC) as PackedScene
	if ps == null:
		return out
	var root := ps.instantiate()
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := (n as MeshInstance3D).mesh
		if mesh != null:
			out[String(n.name)] = _by_id(mesh.surface_get_arrays(0))
	root.free()
	return out
