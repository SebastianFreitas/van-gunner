class_name ItemDefinition
extends Resource

## Data-only description of a single item/boon.
##
## This is intentionally "dumb": it just carries an icon, some flavor text,
## and a list of effects to run on pickup. Anything an item needs to *do*
## lives in its `effects`, so this class never needs to grow new fields as
## the range of items expands.

@export var id: StringName = &""
@export var display_name := "Unknown Item"
@export_multiline var description := ""
@export var icon: Texture2D
## Overrides the pickup's default auto-grab radius when > 0.
@export var pickup_radius := 0.0
@export var effects: Array[ItemEffect] = []


func apply_effects(player: Node3D) -> void:
	for effect in effects:
		if effect:
			effect.apply(player)
