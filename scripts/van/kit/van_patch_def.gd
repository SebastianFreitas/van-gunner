class_name VanPatchDef
extends VanKitDef
## Kit piece type: a repair patch.

@export var source: StringName = &""
## The source's own paint: sign field, fridge enamel, bare steel; unset (black) takes a donor's.
@export var field := Color(0, 0, 0)
## Border and symbol tone of a source that has one (the road sign).
@export var trim := Color(0, 0, 0)
## Symbol shapes a source may roll (the road sign).
@export var symbol_shapes: Array[StringName] = []
