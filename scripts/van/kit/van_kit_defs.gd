class_name VanKitDefs
extends RefCounted
## Loads a folder of kit defs sorted by (order, id) and names a def's RNG stream.


static func load_dir(path: String) -> Array[VanKitDef]:
	var out: Array[VanKitDef] = []
	for file in DirAccess.get_files_at(path):
		if file.ends_with(".tres"):
			var def := load(path.path_join(file)) as VanKitDef
			if def != null:
				out.append(def)
	out.sort_custom(func(a: VanKitDef, b: VanKitDef) -> bool:
		return a.order < b.order or (a.order == b.order and String(a.id) < String(b.id)))
	return out


## `&"kit/<pass>"`, or `&"kit/<pass>/g<G>"` for a def added in generation G > 1.
static func stream_key(pass_id: StringName, def: VanKitDef) -> StringName:
	if def.since_gen > 1:
		return StringName("kit/%s/g%d" % [pass_id, def.since_gen])
	return StringName("kit/" + String(pass_id))
