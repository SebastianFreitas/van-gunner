class_name EnemyDefinition
extends Resource

## Data-only description of a spawnable enemy type.
##
## Each enemy is a .tres resource pointing at its scene. EncounterDirector
## instantiates the scene and applies spawn flags (e.g. is_agile) from here.

@export var id: StringName = &""
@export var display_name := "Unknown Enemy"
@export var scene: PackedScene
## Agile raiders climb window bars; door raiders only smash doors.
@export var is_agile := false
