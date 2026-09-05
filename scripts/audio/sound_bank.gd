class_name SoundBank
extends Resource

## Flat list of SoundCues, indexed by id once at load.
##
## Deliberately a single .tres rather than a folder scan like ActCardRegistry:
## cues are dozens of tiny resources and one file keeps them reorderable and
## diffable. Switch to a DirAccess scan if the list ever outgrows the Inspector.

@export var cues: Array[SoundCue] = []

var _by_id := {}


func build_index() -> void:
	_by_id.clear()
	for cue in cues:
		if cue == null or cue.id == &"":
			push_warning("SoundBank: cue with no id, skipped")
			continue
		if _by_id.has(cue.id):
			push_warning("SoundBank: duplicate cue id %s, keeping the first" % cue.id)
			continue
		_by_id[cue.id] = cue


func get_cue(id: StringName) -> SoundCue:
	return _by_id.get(id, null) as SoundCue


func has_cue(id: StringName) -> bool:
	return _by_id.has(id)


## For the debug console `list sounds` command.
func list_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for key in _by_id.keys():
		ids.append(key)
	ids.sort()
	return ids
