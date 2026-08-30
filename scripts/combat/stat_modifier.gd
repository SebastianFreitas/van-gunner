class_name StatModifier
extends Resource

enum Mode {
	ADD,
	MULTIPLY,
}

@export var stat_name: StringName = &"damage_per_shot"
@export var mode: Mode = Mode.ADD
@export var value: float = 0.0
@export var id: StringName = &""
